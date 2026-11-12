"""Audio resolver: turns a track into a YouTube Music URL that mpv can stream (no ads).

Tracks from the YouTube Music catalog already carry their video id. Tracks imported
from Spotify only have artist/title/duration and are searched for here.
"""

import json
import logging
import re
import shutil
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from .config import CACHE_DIR, read_json, write_private

logger = logging.getLogger("senada.resolver")

RESOLVER_CACHE_FILE = CACHE_DIR / "resolved_tracks.json"


def _clean_str(s: str) -> str:
    s = re.sub(r"\(feat\..*?\)", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\[feat\..*?\]", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\s+", " ", s).strip()
    return s


class AudioResolver:
    def __init__(self):
        self._cache = read_json(RESOLVER_CACHE_FILE)

    def _save_cache(self):
        write_private(RESOLVER_CACHE_FILE, self._cache)

    def resolve(self, track_uri: str, title: str, artist: str, duration_ms: int = 0) -> str | None:
        """Resolve a Spotify track to a playable YouTube/YouTube Music URL.
        Returns 'https://music.youtube.com/watch?v={video_id}' or None.
        """
        if track_uri.startswith("yt:track:"):
            return f"https://music.youtube.com/watch?v={track_uri.split(':', 2)[2]}"
        if not title:
            return None

        # Check cache
        if track_uri and track_uri in self._cache:
            video_id = self._cache[track_uri]
            return f"https://music.youtube.com/watch?v={video_id}"

        # 1. Try Innertube YouTube Music API
        video_id = self._search_innertube(title, artist, duration_ms)

        # 2. Fallback to yt-dlp if Innertube fails
        if not video_id:
            video_id = self._search_ytdlp(title, artist, duration_ms)

        if video_id:
            if track_uri:
                self._cache[track_uri] = video_id
                # Keep cache bounded to last 2000 tracks
                if len(self._cache) > 2000:
                    oldest_keys = list(self._cache.keys())[:200]
                    for k in oldest_keys:
                        del self._cache[k]
                self._save_cache()
            return f"https://music.youtube.com/watch?v={video_id}"

        return None

    def _search_innertube(self, title: str, artist: str, duration_ms: int) -> str | None:
        query = f"{artist} - {_clean_str(title)}"
        payload = json.dumps({
            "context": {
                "client": {
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00",
                    "hl": "en",
                }
            },
            "query": query,
            # Filter params for 'Songs' in YouTube Music
            "params": "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFA%3D%3D",
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://music.youtube.com/youtubei/v1/search",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)",
            },
        )

        try:
            with urllib.request.urlopen(req, timeout=6) as resp:
                res = json.loads(resp.read().decode("utf-8"))

            tabs = res.get("contents", {}).get("tabbedSearchResultsRenderer", {}).get("tabs", [])
            if not tabs:
                return None
            section_list = tabs[0].get("tabRenderer", {}).get("content", {}).get("sectionListRenderer", {}).get("contents", [])
            if not section_list:
                return None

            items = section_list[0].get("musicShelfRenderer", {}).get("contents", [])
            candidates = []

            target_sec = duration_ms / 1000 if duration_ms else 0

            for it in items[:6]:
                renderer = it.get("musicResponsiveListItemRenderer", {})
                vid = renderer.get("playlistItemData", {}).get("videoId")
                if not vid:
                    badge = renderer.get("overlay", {}).get("musicItemThumbnailOverlayRenderer", {}).get(
                        "content", {}).get("musicPlayButtonRenderer", {}).get("playNavigationEndpoint", {})
                    vid = badge.get("watchEndpoint", {}).get("videoId")
                if not vid:
                    continue

                flex_columns = renderer.get("flexColumns", [])
                item_title = ""
                dur_sec = 0

                if flex_columns:
                    try:
                        item_title = flex_columns[0]["musicResponsiveListItemFlexColumnRenderer"]["text"]["runs"][0]["text"]
                    except (KeyError, IndexError):
                        pass

                    # Parse duration if available in column 1
                    try:
                        col1_runs = flex_columns[1]["musicResponsiveListItemFlexColumnRenderer"]["text"]["runs"]
                        for r in col1_runs:
                            txt = r.get("text", "").strip()
                            if ":" in txt and all(part.isdigit() for part in txt.split(":")):
                                parts = list(map(int, txt.split(":")))
                                if len(parts) == 2:
                                    dur_sec = parts[0] * 60 + parts[1]
                                elif len(parts) == 3:
                                    dur_sec = parts[0] * 3600 + parts[1] * 60 + parts[2]
                                break
                    except (KeyError, IndexError):
                        pass

                diff = abs(dur_sec - target_sec) if target_sec and dur_sec else 0
                candidates.append((vid, item_title, dur_sec, diff))

            if candidates:
                if target_sec > 0:
                    # Pick candidate with smallest duration difference <= 12 seconds
                    close_matches = [c for c in candidates if c[3] <= 12 and c[2] > 0]
                    if close_matches:
                        close_matches.sort(key=lambda x: x[3])
                        return close_matches[0][0]
                # Default to first song result
                return candidates[0][0]

        except Exception as e:
            logger.debug(f"Innertube search error: {e}")
        return None

    def _search_ytdlp(self, title: str, artist: str, duration_ms: int) -> str | None:
        ytdlp_bin = shutil.which("yt-dlp")
        if not ytdlp_bin:
            local_bin = Path.home() / ".local" / "bin" / "yt-dlp"
            if local_bin.exists():
                ytdlp_bin = str(local_bin)
            else:
                return None

        query = f"ytsearch3:{artist} - {_clean_str(title)} audio"
        try:
            res = subprocess.run(
                [ytdlp_bin, "--dump-json", "--flat-playlist", query],
                capture_output=True,
                text=True,
                timeout=8,
            )
            target_sec = duration_ms / 1000 if duration_ms else 0
            best_id = None
            min_diff = 999999

            for line in res.stdout.strip().splitlines():
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    vid = data.get("id")
                    dur = data.get("duration") or 0
                    if not vid:
                        continue
                    if not best_id:
                        best_id = vid
                    if target_sec and dur:
                        diff = abs(dur - target_sec)
                        if diff < min_diff and diff <= 15:
                            min_diff = diff
                            best_id = vid
                except json.JSONDecodeError:
                    continue

            return best_id
        except Exception as e:
            logger.debug(f"yt-dlp search error: {e}")
        return None
