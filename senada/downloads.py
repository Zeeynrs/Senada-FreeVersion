"""Songs kept on this device to play without internet (the "Offline songs" playlist).

yt-dlp saves the song's own YouTube audio stream (m4a, or webm when there is no m4a) as it
is: nothing is re-encoded, so ffmpeg is not needed. The cover and the lyrics are saved
with it, so a downloaded song also shows its art and lyrics offline. downloads.json in the
settings folder lists what is there; the files live in DOWNLOADS_DIR (Music/Senada).

Downloads run one at a time on their own thread; results reach the UI thread through a
signal, like the worker's.
"""

import copy
import glob
import logging
import re
import subprocess
import threading
import time
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices

from . import net
from .childproc import kill_tree
from .config import DOWNLOADS_DIR, DOWNLOADS_FILE, NO_WINDOW, read_json, write_private
from .i18n import tr, trn
from .store import _clean_track
from .streams import AUDIO_FORMAT, PLAYER_ARGS, is_blocked, watch_url

logger = logging.getLogger("senada.downloads")

TIMEOUT = 900          # seconds before a stuck download is stopped
AUDIO_EXTS = (".m4a", ".webm", ".opus", ".mp3", ".ogg", ".aac", ".mka")
UNSAFE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
PROGRESS_RE = re.compile(r"^SENADA (\S+) (\S+) (\S+)")
PROGRESS_TEMPLATE = ("download:SENADA %(progress.downloaded_bytes)s %(progress.total_bytes)s "
                     "%(progress.total_bytes_estimate)s")
IMAGE_KEYS = ("imageSmall", "image", "imageLarge")

# stateOf(): 0-100 while downloading
DONE = 101
QUEUED = -1
NONE = -2


class DownloadError(Exception):
    pass


class Cancelled(Exception):
    pass


def safe_name(text: str) -> str:
    """A file name that works on Windows, macOS and Linux."""
    return re.sub(r"\s+", " ", UNSAFE.sub("_", text or "")).strip(" .")[:100] or "song"


def human_size(n: float) -> str:
    for unit in ("B", "KB", "MB"):
        if n < 1024:
            return f"{n:.0f} {unit}" if unit != "MB" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.2f} GB"


def _number(text: str) -> float:
    try:
        return float(text)
    except ValueError:  # "NA"
        return 0.0


class Downloads(QObject):
    changed = Signal()           # the list of downloaded songs
    progressChanged = Signal()   # what is downloading and how far along it is
    toast = Signal(str)
    _event = Signal(object)      # download thread -> UI thread

    def __init__(self, resolver=None, folder: Path = DOWNLOADS_DIR, index_file: Path = DOWNLOADS_FILE,
                 start: bool = True, parent=None):
        super().__init__(parent)
        self.resolver = resolver
        self.folder = Path(folder)
        self.index_file = Path(index_file)
        self._lock = threading.RLock()
        self._wake = threading.Condition(self._lock)
        saved = read_json(self.index_file).get("songs") or []
        self._items = [e for e in saved if isinstance(e, dict) and e.get("uri") and e.get("file")
                       and (self.folder / e["file"]).is_file()]  # files deleted by hand are forgotten
        if len(self._items) != len(saved):
            self._save()
        self._queue: list[dict] = []
        self._current: dict | None = None  # {"track", "progress", "proc", "cancelled"}
        self._revision = 0
        self._progress_revision = 0
        self._last_progress = 0.0
        self._event.connect(self._on_event)
        if start:
            threading.Thread(target=self._run, name="senada-downloads", daemon=True).start()

    # ---- for Python (player, lyrics, catalog) -----------------------------------------

    def _save(self):
        with self._lock:
            write_private(self.index_file, {"songs": self._items})

    def _find(self, uri: str) -> dict | None:
        return next((e for e in self._items if e["uri"] == uri), None)

    def path_for(self, uri: str) -> str | None:
        """The downloaded audio file of this song, if there is one."""
        with self._lock:
            e = self._find(uri)
            path = self.folder / e["file"] if e else None
        return str(path) if path and path.is_file() else None

    def video_id_for(self, uri: str) -> str:
        """The YouTube upload a downloaded song came from."""
        with self._lock:
            e = self._find(uri)
            return e.get("videoId", "") if e else ""

    def lyrics_for(self, uri: str) -> dict | None:
        with self._lock:
            e = self._find(uri)
            return copy.deepcopy(e.get("lyrics")) if e and e.get("lyrics") else None

    def tracks(self) -> list[dict]:
        """Downloaded songs, newest first, as track dicts for the pages."""
        with self._lock:
            return [{k: v for k, v in e.items() if k not in ("lyrics", "file", "cover")} for e in self._items]

    def total_size(self) -> int:
        with self._lock:
            return sum(e.get("size", 0) for e in self._items)

    def page(self) -> dict:
        tracks = self.tracks()
        note = tr("Nothing downloaded yet. Right-click any song → Download, or use the download button "
                  "of a playlist or album, to listen without internet.") if not tracks else ""
        cover = next((t for t in tracks if t.get("imageSmall")), {})
        return {"kind": "offline", "id": "", "uri": "senada:offline:", "name": tr("Offline songs"),
                **{k: cover.get(k, "") for k in IMAGE_KEYS},
                "typeLabel": tr("Playlist"),
                "subtitle": trn("{n} song", "{n} songs", len(tracks)) + " • " + human_size(self.total_size())
                            + " • " + tr("plays without internet"),
                "tracks": tracks, "playUri": "senada:offline:", "note": note, "offline": True}

    def enqueue(self, tracks: list[dict]) -> int:
        """Queue songs that are neither downloaded nor on their way; returns how many."""
        added = 0
        with self._lock:
            busy = {t["uri"] for t in self._queue}
            if self._current:
                busy.add(self._current["track"]["uri"])
            for t in tracks:
                uri = t.get("uri") or ""
                if not uri or uri in busy or self._find(uri):
                    continue
                if not uri.startswith(("yt:track:", "spotify:track:")):
                    continue
                self._queue.append(dict(t))
                busy.add(uri)
                added += 1
            if added:
                self._wake.notify()
        return added

    # ---- the download thread ----------------------------------------------------------

    def _run(self):
        while True:
            with self._lock:
                while not self._queue:
                    self._wake.wait()
            self.process_next()

    def process_next(self):
        """Download the first waiting song (the download thread calls this in a loop)."""
        with self._lock:
            if not self._queue:
                return
            track = self._queue.pop(0)
            job = self._current = {"track": track, "progress": 0, "proc": None, "cancelled": False}
        self._event.emit(("progress",))
        entry, problem = None, ""
        try:
            entry = self._download(job)
        except Cancelled:
            pass
        except Exception as e:  # one song failing must not stop the others
            problem = str(e) or e.__class__.__name__
            logger.warning("download of %s failed: %s", track.get("uri"), problem)
        with self._lock:
            cancelled = job["cancelled"]
            self._current = None
            if entry and not cancelled:
                self._items = [e for e in self._items if e["uri"] != entry["uri"]]
                self._items.insert(0, entry)
                self._save()
        if cancelled:
            self._cleanup(job.get("base", ""))
            self._event.emit(("cancelled", track))
        elif entry:
            self._event.emit(("done", track))
        else:
            self._cleanup(job.get("base", ""))
            self._event.emit(("failed", track, problem))

    def _download(self, job: dict) -> dict:
        track = job["track"]
        uri = track["uri"]
        video_id = uri.split(":", 2)[2] if uri.startswith("yt:track:") else ""
        if not video_id and self.resolver is not None:  # an imported song: its YouTube Music match
            video_id = (self.resolver.match(track) or {}).get("v", "")
        if not video_id:
            raise DownloadError(tr("not found on YouTube Music"))
        artist = (track.get("artists") or "").split(",")[0].strip()
        base = job["base"] = safe_name(f"{artist} - {track.get('name', '')}" if artist else track.get("name", "")) \
            + f" [{video_id}]"
        self.folder.mkdir(parents=True, exist_ok=True)
        audio = self._fetch_audio(job, video_id, base)
        cover = self._fetch_cover(track, base)
        lyrics = self._fetch_lyrics(track, video_id)
        entry = {**_clean_track(track), "videoId": video_id, "file": audio.name, "size": audio.stat().st_size,
                 "cover": cover.name if cover else "", "lyrics": lyrics, "downloadedAt": int(time.time())}
        if cover:  # the saved cover, so it also shows offline
            entry.update({k: cover.as_uri() for k in IMAGE_KEYS})
        return entry

    def _audio_file(self, base: str) -> Path | None:
        for p in self.folder.glob(glob.escape(base) + ".*"):
            if p.suffix.lower() in AUDIO_EXTS and p.is_file():
                return p
        return None

    def _fetch_audio(self, job: dict, video_id: str, base: str) -> Path:
        from .engine import find_tool
        ytdlp = find_tool("yt-dlp")
        if not ytdlp:
            raise DownloadError(tr("yt-dlp was not found"))
        template = str(self.folder / (base.replace("%", "%%") + ".%(ext)s"))
        problem = ""
        for extra in PLAYER_ARGS:  # the quick player first, like streaming does
            cmd = [ytdlp, "--no-warnings", "--no-playlist", "--socket-timeout", "15", *extra,
                   "-f", AUDIO_FORMAT, "--no-mtime", "--newline", "--progress-template", PROGRESS_TEMPLATE,
                   "-o", template, watch_url(video_id)]
            ok, said = self._run_ytdlp(job, cmd)
            found = self._audio_file(base)
            if ok and found:
                return found
            problem = said or problem
            if is_blocked(said):
                break
        raise DownloadError(problem or tr("yt-dlp could not download the song"))

    def _run_ytdlp(self, job: dict, cmd: list[str]) -> tuple[bool, str]:
        if job["cancelled"]:
            raise Cancelled()
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                    text=True, encoding="utf-8", errors="replace", creationflags=NO_WINDOW)
        except OSError as e:
            raise DownloadError(tr("yt-dlp could not be started: {error}", error=e)) from e
        with self._lock:
            job["proc"] = proc
        watchdog = threading.Timer(TIMEOUT, kill_tree, args=(proc,))
        watchdog.daemon = True
        watchdog.start()
        said = ""
        try:
            for line in proc.stdout:
                line = line.strip()
                m = PROGRESS_RE.match(line)
                if m:
                    done, total, estimate = (_number(x) for x in m.groups())
                    total = total or estimate
                    if total > 0:
                        job["progress"] = max(0, min(99, int(done * 100 / total)))
                        now = time.monotonic()
                        if now - self._last_progress > 0.3:
                            self._last_progress = now
                            self._event.emit(("progress",))
                elif line.startswith("ERROR:"):
                    said = line[:200]
            code = proc.wait()
        finally:
            watchdog.cancel()
            proc.stdout.close()
            with self._lock:
                job["proc"] = None
        if job["cancelled"]:
            raise Cancelled()
        return code == 0, said

    def _fetch_cover(self, track: dict, base: str) -> Path | None:
        url = track.get("imageLarge") or track.get("image") or track.get("imageSmall") or ""
        if not url.startswith("http"):
            return None
        try:
            with net.urlopen(url, timeout=15) as resp:
                data = resp.read()
        except OSError as e:
            logger.info("cover not saved: %s", e)
            return None
        path = self.folder / (base + ".jpg")
        try:
            path.write_bytes(data)
        except OSError:
            return None
        return path

    @staticmethod
    def _fetch_lyrics(track: dict, video_id: str) -> dict | None:
        from .lyrics import fetch_lyrics
        try:
            found = fetch_lyrics({**track, "videoId": video_id}, "auto")
        except Exception as e:  # lyrics are a bonus: the song is downloaded without them
            logger.info("lyrics not saved: %s", e)
            return None
        return found if found.get("lines") else None

    def _cleanup(self, base: str):
        """Remove what a cancelled or failed download left behind."""
        if not base:
            return
        for p in self.folder.glob(glob.escape(base) + ".*"):
            try:
                p.unlink()
            except OSError:
                pass

    # ---- UI thread -----------------------------------------------------------------------

    def _on_event(self, event):
        kind = event[0]
        self._progress_revision += 1
        self.progressChanged.emit()
        if kind == "progress":
            return
        name = event[1].get("name", "")
        if kind == "done":
            self._revision += 1
            self.changed.emit()
            with self._lock:
                left = len(self._queue) + (1 if self._current else 0)
            if not left:
                self.toast.emit(tr("“{name}” is downloaded — it plays without internet now", name=name))
        elif kind == "failed":
            self.toast.emit(tr("“{name}” could not be downloaded: {error}", name=name, error=event[2]))

    # ---- QML ------------------------------------------------------------------------------

    @Property(int, notify=changed)
    def revision(self):
        return self._revision

    @Property(int, notify=progressChanged)
    def progressRevision(self):
        return self._progress_revision

    @Property(int, notify=changed)
    def count(self):
        with self._lock:
            return len(self._items)

    @Property(str, notify=changed)
    def sizeText(self):
        return human_size(self.total_size())

    @Property(str, constant=True)
    def folderPath(self):
        return str(self.folder)

    @Property(int, notify=progressChanged)
    def pending(self):
        """Songs waiting or downloading right now."""
        with self._lock:
            return len(self._queue) + (1 if self._current else 0)

    @Property("QVariantMap", notify=progressChanged)
    def current(self):
        with self._lock:
            if not self._current:
                return {}
            return {"uri": self._current["track"].get("uri", ""), "name": self._current["track"].get("name", ""),
                    "progress": self._current["progress"]}

    @Slot(str, result=int)
    def stateOf(self, uri):
        """101 downloaded, 0-100 downloading, -1 waiting, -2 not downloaded."""
        with self._lock:
            if self._current and self._current["track"].get("uri") == uri:
                return self._current["progress"]
            if any(t["uri"] == uri for t in self._queue):
                return QUEUED
            return DONE if self._find(uri) else NONE

    @Slot("QVariantList", result=int)
    def downloadedCount(self, uris):
        with self._lock:
            have = {e["uri"] for e in self._items}
        return sum(1 for u in uris or [] if u in have)

    @Slot("QVariantList")
    def download(self, tracks):
        tracks = [dict(t) for t in tracks or [] if t]
        added = self.enqueue(tracks)
        self._progress_revision += 1
        self.progressChanged.emit()
        if added == 1:
            name = next((t.get("name", "") for t in tracks if self.stateOf(t.get("uri", "")) != DONE), "")
            self.toast.emit(tr("Downloading “{name}”…", name=name))
        elif added:
            self.toast.emit(trn("Downloading {n} song…", "Downloading {n} songs…", added))
        elif tracks:
            self.toast.emit(tr("Already downloaded"))

    @Slot(str)
    def remove(self, uri):
        """Cancel a waiting or running download, or delete a downloaded song."""
        what = self._remove(uri)
        if what == "cancelled":
            self.toast.emit(tr("Download cancelled"))
        elif what == "deleted":
            self.toast.emit(tr("Removed from Offline songs"))

    def _remove(self, uri: str) -> str:
        with self._lock:
            before = len(self._queue)
            self._queue = [t for t in self._queue if t["uri"] != uri]
            dropped = before != len(self._queue)
            proc = None
            if self._current and self._current["track"].get("uri") == uri:
                self._current["cancelled"] = True
                proc = self._current["proc"]
                dropped = True
            entry = self._find(uri)
            if entry and not dropped:
                self._items = [e for e in self._items if e["uri"] != uri]
                self._save()
        if proc is not None:
            kill_tree(proc)
        if dropped:
            self._progress_revision += 1
            self.progressChanged.emit()
            return "cancelled"
        if entry:
            for name in (entry.get("file"), entry.get("cover")):
                if name:
                    try:
                        (self.folder / name).unlink()
                    except OSError:
                        pass
            self._revision += 1
            self.changed.emit()
            return "deleted"
        return ""

    @Slot()
    def cancelAll(self):
        with self._lock:
            uris = [t["uri"] for t in self._queue]
            if self._current:
                uris.append(self._current["track"]["uri"])
        for uri in uris:
            self._remove(uri)
        if uris:
            self.toast.emit(tr("Download cancelled"))

    @Slot()
    def openFolder(self):
        self.folder.mkdir(parents=True, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.folder)))
