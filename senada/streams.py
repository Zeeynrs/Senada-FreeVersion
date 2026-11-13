"""Direct audio stream addresses for YouTube Music tracks.

Handing mpv a watch link makes its yt-dlp hook look the stream up when the track starts,
which takes many seconds (about 8 on Windows) before any sound. Here yt-dlp is run by
Senada itself, off the UI thread and ahead of time for the next track; mpv then gets the
finished address and starts almost at once. Addresses stay valid for a few hours, so they
are kept in memory until shortly before they expire.

YouTube holds a stream back (HTTP 403) for the length of the skippable ad its player would
show, about 5 seconds after the address is issued; yt-dlp reports that as "available_at".
The visionOS player gets no such ad and needs no JavaScript challenge, so it is asked
first: full quality, usable at once, in about half the time. If that ever stops working,
yt-dlp's default players are used and the address is only handed out once it works.
"""

import json
import logging
import re
import subprocess
import threading
import time

from .config import NO_WINDOW

logger = logging.getLogger("senada.streams")

AUDIO_FORMAT = "bestaudio[ext=m4a]/bestaudio/best"
# tried in order: the quick player first, then yt-dlp's own default choice
PLAYER_ARGS = (["--extractor-args", "youtube:player_client=visionos"], [])
MAX_HOLD = 12         # longest wait (seconds) for an address that is not usable yet
TIMEOUT = 30          # seconds before a stuck yt-dlp is killed
DEFAULT_TTL = 3600    # when the address does not say when it expires
FRESH_MARGIN = 1800   # an address must stay valid this long to be used for a new playback
CACHE_LIMIT = 300


# YouTube's answer when it is limiting a network for a while ("confirm you're not a bot", HTTP 429):
# every song fails the same way then, so trying other uploads or the next songs only makes it worse
BLOCKED_RE = re.compile(r"not a bot|HTTP Error 429|Too Many Requests", re.I)


def is_blocked(message) -> bool:
    return bool(BLOCKED_RE.search(str(message or "")))


class StreamError(Exception):
    pass


def watch_url(video_id: str) -> str:
    return f"https://music.youtube.com/watch?v={video_id}"


class StreamResolver:
    def __init__(self):
        self._lock = threading.Lock()
        self._cache: dict[str, dict] = {}              # video id -> {"url", "expires", "available"}
        self._running: dict[str, threading.Event] = {}  # lookups in progress

    def cached(self, video_id: str) -> str | None:
        """The stream address if one is known, usable now and still valid long enough to play."""
        now = time.time()
        with self._lock:
            entry = self._cache.get(video_id)
            if entry and entry["available"] <= now and entry["expires"] - now > FRESH_MARGIN:
                return entry["url"]
        return None

    def forget(self, video_id: str) -> None:
        with self._lock:
            self._cache.pop(video_id, None)

    def resolve(self, video_id: str) -> str:
        """The stream address, looked up with yt-dlp when needed (blocking: call off the UI thread)."""
        while True:
            url = self.cached(video_id)
            if url:
                return url
            with self._lock:
                running = self._running.get(video_id)
                if running is None:
                    running = self._running[video_id] = threading.Event()
                    break
            running.wait(TIMEOUT + 5)  # the same track is already being looked up (prefetch): share it
            url = self.cached(video_id)
            if url:
                return url
            if running.is_set():
                raise StreamError("yt-dlp found no audio stream")
        try:
            url, available = self._fetch(video_id)
            expires = re.search(r"[?&/]expire[=/](\d{9,})", url)
            with self._lock:
                self._cache.pop(video_id, None)
                self._cache[video_id] = {"url": url, "available": available,
                                         "expires": int(expires.group(1)) if expires else time.time() + DEFAULT_TTL}
                for old in list(self._cache)[: max(0, len(self._cache) - CACHE_LIMIT)]:
                    del self._cache[old]
            hold = available - time.time()
            if hold > 0:  # opening it earlier only gets HTTP 403
                time.sleep(min(hold, MAX_HOLD))
            return url
        finally:
            with self._lock:
                self._running.pop(video_id, None)
            running.set()

    def _fetch(self, video_id: str) -> tuple[str, float]:
        """(stream address, unix time from which it works)."""
        from .engine import find_tool
        ytdlp = find_tool("yt-dlp")
        if not ytdlp:
            raise StreamError("yt-dlp was not found")
        started, problem = time.monotonic(), "yt-dlp found no audio stream"
        for extra in PLAYER_ARGS:
            try:
                found = self._run(ytdlp, extra, video_id)
            except StreamError as e:
                problem = str(e)
                logger.info("yt-dlp %s failed for %s: %s", extra, video_id, e)
                continue
            logger.info("stream for %s in %.1fs", video_id, time.monotonic() - started)
            return found
        raise StreamError(problem)

    def _run(self, ytdlp: str, extra: list[str], video_id: str) -> tuple[str, float]:
        cmd = [ytdlp, "--no-warnings", "--no-playlist", "--socket-timeout", "10", *extra,
               "-f", AUDIO_FORMAT, "-O", "%(.{url,available_at})j", watch_url(video_id)]
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                    text=True, encoding="utf-8", errors="replace", creationflags=NO_WINDOW)
        except OSError as e:
            raise StreamError(f"yt-dlp could not be started: {e}") from e
        watchdog = threading.Timer(TIMEOUT, proc.kill)
        watchdog.daemon = True
        watchdog.start()
        found, said = {}, []
        try:
            for line in proc.stdout:
                line = line.strip()
                if line.startswith("{"):
                    try:
                        found = json.loads(line)
                    except ValueError:
                        found = {}
                    if found.get("url"):
                        break  # the answer is here: no need to wait for yt-dlp to shut down
                elif line:
                    said.append(line)
        finally:
            # yt-dlp needs a moment to exit; that must not delay playback
            threading.Thread(target=self._reap, args=(proc, watchdog), daemon=True).start()
        if not found.get("url"):
            raise StreamError((said[-1] if said else "yt-dlp found no audio stream")[:200])
        try:
            available = float(found.get("available_at") or 0)
        except (TypeError, ValueError):
            available = 0.0
        return found["url"], available

    @staticmethod
    def _reap(proc, watchdog):
        try:
            proc.stdout.read()
            proc.wait()
        except (OSError, ValueError):
            pass
        finally:
            watchdog.cancel()
            proc.stdout.close()
