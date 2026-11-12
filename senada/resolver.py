"""Audio resolver: turns a track into a YouTube Music URL that mpv can stream (no ads).

Tracks from the YouTube Music catalog already carry their video id. Tracks imported
from Spotify only have artist/title/duration; they are matched here with the scoring
in `matching.py`:

  1. YouTube Music "Songs" search (official audio)  -> stop if the best match is confident
  2. YouTube Music "Videos" search                  -> music videos and uploads
  3. yt-dlp search                                  -> only if nothing usable was found

Matches are cached per track (with the matcher version, so improved scoring re-checks
old guesses), and a manual pick from "Pilih versi lain…" always wins.
"""

import json
import logging
import subprocess
import threading

from . import matching, ytmusic
from .config import CACHE_DIR, NO_WINDOW, read_json, write_private

logger = logging.getLogger("senada.resolver")

RESOLVER_CACHE_FILE = CACHE_DIR / "resolved_tracks.json"
CACHE_LIMIT = 3000


def watch_url(video_id: str) -> str:
    return f"https://music.youtube.com/watch?v={video_id}"


class AudioResolver:
    def __init__(self):
        self._lock = threading.RLock()
        raw = read_json(RESOLVER_CACHE_FILE)
        # keep only entries written by this matcher (or picked by hand); older guesses are redone
        self._cache = {k: v for k, v in raw.items()
                       if isinstance(v, dict) and (v.get("manual") or v.get("m") == matching.MATCHER_VERSION)}

    def _save_cache(self):
        with self._lock:
            if len(self._cache) > CACHE_LIMIT:
                for key in list(self._cache)[: len(self._cache) - CACHE_LIMIT]:
                    del self._cache[key]
            write_private(RESOLVER_CACHE_FILE, self._cache)

    def _remember(self, uri: str, cand: dict, manual: bool = False):
        entry = {
            "v": cand["id"],
            "s": (cand.get("match") or {}).get("score", 100 if manual else 0),
            "m": matching.MATCHER_VERSION,
            "name": cand.get("name", ""),
            "artists": cand.get("artists", ""),
            "imageSmall": cand.get("imageSmall", ""),
            "image": cand.get("image", ""),
            "imageLarge": cand.get("imageLarge", ""),
        }
        if manual:
            entry["manual"] = True
        with self._lock:
            self._cache.pop(uri, None)
            self._cache[uri] = entry  # re-insert so recently used entries survive trimming
            self._save_cache()
        return entry

    # ---- public API ------------------------------------------------------------

    def cached(self, uri: str) -> dict | None:
        with self._lock:
            entry = self._cache.get(uri)
            return dict(entry) if entry else None

    def resolve(self, track_uri: str, title: str, artist: str, duration_ms: int = 0, album: str = "") -> str | None:
        """A playable YouTube Music URL for the track, or None."""
        if track_uri.startswith("yt:track:"):
            return watch_url(track_uri.split(":", 2)[2])
        info = self.match({"uri": track_uri, "name": title, "artists": artist,
                           "durationMs": duration_ms, "album": album})
        return watch_url(info["v"]) if info else None

    def match(self, track: dict) -> dict | None:
        """Cache entry {v, s, name, artists, image…} for a metadata-only track, searching if needed."""
        uri = track.get("uri") or ""
        if uri.startswith("yt:track:"):
            return {"v": uri.split(":", 2)[2], "s": 100}
        if uri:
            hit = self.cached(uri)
            if hit:
                return hit
        if not track.get("name"):
            return None
        ranked = self.candidates(track)
        best = ranked[0] if ranked else None
        if not best or best["match"]["score"] < matching.MINIMUM:
            logger.info("no confident match for %s - %s (best %s)", track.get("artists"), track.get("name"),
                        best["match"]["score"] if best else None)
            return None
        return self._remember(uri, best) if uri else {"v": best["id"], "s": best["match"]["score"]}

    def candidates(self, track: dict, thorough: bool = False) -> list[dict]:
        """Scored candidates, best first. `thorough` always runs every search stage
        (used by the "Pilih versi lain…" picker)."""
        query = matching.search_query(track)
        found = []
        try:
            found += ytmusic.search_tracks(query)
        except ytmusic.YTMusicError as e:
            logger.debug("songs search failed: %s", e)
        ranked = matching.rank(track, found)
        if thorough or not ranked or ranked[0]["match"]["score"] < matching.ACCEPT:
            try:
                found += ytmusic.search_tracks(query, videos=True)
            except ytmusic.YTMusicError as e:
                logger.debug("videos search failed: %s", e)
            ranked = matching.rank(track, found)
        if not ranked or ranked[0]["match"]["score"] < matching.MINIMUM:
            found += self._search_ytdlp(query)
            ranked = matching.rank(track, found)
        return ranked

    def choose(self, track: dict, cand: dict) -> dict:
        """Remember the user's pick for this track."""
        return self._remember(track.get("uri") or "", cand, manual=True)

    # ---- yt-dlp fallback ----------------------------------------------------------

    def _search_ytdlp(self, query: str) -> list[dict]:
        from .engine import find_tool
        ytdlp_bin = find_tool("yt-dlp")
        if not ytdlp_bin:
            return []
        try:
            res = subprocess.run([ytdlp_bin, "--dump-json", "--flat-playlist", f"ytsearch5:{query}"],
                                 capture_output=True, text=True, encoding="utf-8", errors="replace",
                                 timeout=12, creationflags=NO_WINDOW)
        except (OSError, subprocess.SubprocessError) as e:
            logger.debug("yt-dlp search error: %s", e)
            return []
        out = []
        for line in res.stdout.splitlines():
            try:
                data = json.loads(line)
            except ValueError:
                continue
            vid = data.get("id")
            if not vid:
                continue
            thumb = f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"
            out.append(ytmusic.make_track(
                vid, data.get("title") or "", data.get("channel") or data.get("uploader") or "",
                images=(thumb, thumb, thumb), duration=int((data.get("duration") or 0) * 1000),
                video_type="MUSIC_VIDEO_TYPE_UGC"))
        return out
