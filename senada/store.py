"""Local library kept on disk: liked songs, own playlists, saved albums/playlists, history.

Everything lives in ~/.config/senada/library.json, so Senada needs no account.
Thread-safe: worker threads and the UI thread both read and write it.
"""

import copy
import threading
import time
import uuid

from .config import LIBRARY_FILE, read_json, write_private

HISTORY_LIMIT = 200
TRACK_KEYS = ("uri", "id", "name", "artists", "artistId", "album", "albumId",
              "imageSmall", "image", "imageLarge", "durationMs", "explicit")


def _clean_track(track: dict) -> dict:
    return {k: track.get(k, "" if k not in ("durationMs", "explicit") else (0 if k == "durationMs" else False))
            for k in TRACK_KEYS}


class LocalStore:
    def __init__(self, path=LIBRARY_FILE):
        self.path = path
        self._lock = threading.RLock()
        data = read_json(path)
        self._data = {
            "liked": data.get("liked") or [],
            "playlists": data.get("playlists") or [],
            "saved": data.get("saved") or [],
            "history": data.get("history") or [],
        }

    def _save(self):
        write_private(self.path, self._data)

    # ---- liked songs -----------------------------------------------------

    def liked(self) -> list[dict]:
        with self._lock:
            return copy.deepcopy(self._data["liked"])

    def is_liked(self, uri: str) -> bool:
        with self._lock:
            return any(t["uri"] == uri for t in self._data["liked"])

    def set_liked(self, track: dict, liked: bool) -> bool:
        """Returns True when something changed."""
        uri = track.get("uri") if track else ""
        if not uri:
            return False
        with self._lock:
            had = self.is_liked(uri)
            if liked == had:
                return False
            if liked:
                self._data["liked"].insert(0, {**_clean_track(track), "addedAt": int(time.time())})
            else:
                self._data["liked"] = [t for t in self._data["liked"] if t["uri"] != uri]
            self._save()
            return True

    # ---- own playlists -----------------------------------------------------

    def playlists(self) -> list[dict]:
        """Own playlists without their track lists (for menus and the sidebar)."""
        with self._lock:
            return [{k: v for k, v in p.items() if k != "tracks"} | {"count": len(p["tracks"])}
                    for p in self._data["playlists"]]

    def playlist(self, pid: str) -> dict | None:
        with self._lock:
            p = next((p for p in self._data["playlists"] if p["id"] == pid), None)
            return copy.deepcopy(p) if p else None

    def create_playlist(self, name: str, tracks: list[dict] | None = None, source: str = "",
                        description: str = "") -> str:
        pid = "local-" + uuid.uuid4().hex[:12]
        with self._lock:
            self._data["playlists"].insert(0, {
                "id": pid,
                "name": (name or "").strip() or "Playlist baru",
                "description": description,
                "source": source,
                "created": int(time.time()),
                "tracks": [_clean_track(t) for t in tracks or [] if t.get("uri")],
            })
            self._save()
        return pid

    def rename_playlist(self, pid: str, name: str) -> bool:
        name = (name or "").strip()
        with self._lock:
            for p in self._data["playlists"]:
                if p["id"] == pid and name and p["name"] != name:
                    p["name"] = name
                    self._save()
                    return True
        return False

    def delete_playlist(self, pid: str) -> bool:
        with self._lock:
            before = len(self._data["playlists"])
            self._data["playlists"] = [p for p in self._data["playlists"] if p["id"] != pid]
            if len(self._data["playlists"]) != before:
                self._save()
                return True
        return False

    def add_to_playlist(self, pid: str, tracks: list[dict]) -> int:
        """Append tracks that are not in the playlist yet; returns how many were added."""
        with self._lock:
            p = next((p for p in self._data["playlists"] if p["id"] == pid), None)
            if not p:
                return 0
            have = {t["uri"] for t in p["tracks"]}
            new = [_clean_track(t) for t in tracks if t.get("uri") and t["uri"] not in have]
            if new:
                p["tracks"].extend(new)
                self._save()
            return len(new)

    def remove_from_playlist(self, pid: str, uri: str) -> bool:
        with self._lock:
            p = next((p for p in self._data["playlists"] if p["id"] == pid), None)
            if not p:
                return False
            before = len(p["tracks"])
            p["tracks"] = [t for t in p["tracks"] if t["uri"] != uri]
            if len(p["tracks"]) != before:
                self._save()
                return True
        return False

    # ---- saved albums / playlists (bookmarks of catalog pages) -----------------

    def saved(self) -> list[dict]:
        with self._lock:
            return copy.deepcopy(self._data["saved"])

    def is_saved(self, kind: str, cid: str) -> bool:
        with self._lock:
            return any(s["kind"] == kind and s["id"] == cid for s in self._data["saved"])

    def set_saved(self, card: dict, saved: bool) -> bool:
        kind, cid = card.get("kind", ""), card.get("id", "")
        if not kind or not cid:
            return False
        with self._lock:
            if saved == self.is_saved(kind, cid):
                return False
            if saved:
                keep = ("kind", "id", "uri", "name", "subtitle", "imageSmall", "image", "imageLarge")
                self._data["saved"].insert(0, {k: card.get(k, "") for k in keep})
            else:
                self._data["saved"] = [s for s in self._data["saved"] if not (s["kind"] == kind and s["id"] == cid)]
            self._save()
            return True

    # ---- history -------------------------------------------------------------

    def add_history(self, track: dict):
        uri = track.get("uri") if track else ""
        if not uri:
            return
        with self._lock:
            hist = [t for t in self._data["history"] if t["uri"] != uri]
            hist.insert(0, {**_clean_track(track), "playedAt": int(time.time())})
            self._data["history"] = hist[:HISTORY_LIMIT]
            self._save()

    def history(self, limit: int = 50) -> list[dict]:
        with self._lock:
            return copy.deepcopy(self._data["history"][:limit])
