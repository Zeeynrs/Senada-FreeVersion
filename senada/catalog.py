"""One place that knows where each collection comes from.

ids:  local-xxxx -> own playlist (LocalStore)
      sp-xxxx    -> public Spotify playlist/album (embed page)
      anything else -> YouTube Music (album MPREb_…, artist UC…, playlist PL…/RDCLAK…/OLAK…)
uris: senada:<kind>:<id> for collections, yt:track:<videoId> / spotify:track:<id> for tracks.
"""

import threading
import time

from . import spotify_import, ytmusic
from .store import LocalStore

CACHE_TTL = 600  # seconds a remote page stays fresh


class Catalog:
    def __init__(self, store: LocalStore):
        self.store = store
        self._cache = {}
        self._lock = threading.Lock()

    def _cached(self, key, fetch):
        now = time.monotonic()
        with self._lock:
            hit = self._cache.get(key)
            if hit and now - hit[0] < CACHE_TTL:
                return hit[1]
        value = fetch()
        with self._lock:
            self._cache[key] = (now, value)
            if len(self._cache) > 64:
                oldest = min(self._cache, key=lambda k: self._cache[k][0])
                del self._cache[oldest]
        return value

    # ---- collections ---------------------------------------------------------

    def liked_page(self) -> dict:
        tracks = self.store.liked()
        return {"kind": "liked", "id": "", "uri": "senada:liked:", "name": "Lagu yang Disukai",
                "typeLabel": "Playlist", "subtitle": f"{len(tracks)} lagu • tersimpan di perangkat ini",
                "tracks": tracks, "playUri": "senada:liked:"}

    def local_page(self, pid: str) -> dict:
        p = self.store.playlist(pid)
        if not p:
            raise LookupError("Playlist ini sudah dihapus.")
        tracks = p["tracks"]
        cover = next((t for t in tracks if t.get("imageSmall")), {})
        note = ""
        if not tracks:
            note = "Playlist masih kosong. Klik kanan lagu mana pun → Tambah ke playlist."
        elif p.get("source"):
            note = "Diimpor dari " + p["source"]
        return {"kind": "playlist", "id": pid, "uri": f"senada:playlist:{pid}", "name": p["name"],
                "typeLabel": "Playlist Saya", "subtitle": "Disimpan di perangkat ini",
                "description": p.get("description", ""), "local": True,
                "imageSmall": cover.get("imageSmall", ""), "image": cover.get("image", ""),
                "imageLarge": cover.get("imageLarge", ""), "tracks": tracks, "note": note,
                "playUri": f"senada:playlist:{pid}"}

    def load(self, kind: str, cid: str) -> dict:
        if kind == "liked":
            return self.liked_page()
        if kind == "playlist" and cid.startswith("local-"):
            return self.local_page(cid)
        if cid.startswith("sp-"):
            return self._cached((kind, cid), lambda: spotify_import.fetch(kind, cid[3:]))
        if kind == "playlist":
            return self._cached((kind, cid), lambda: ytmusic.playlist(cid))
        if kind == "album":
            return self._cached((kind, cid), lambda: ytmusic.album(cid))
        if kind == "artist":
            return self._cached((kind, cid), lambda: ytmusic.artist(cid))
        raise LookupError(f"Jenis halaman tidak dikenal: {kind}")

    def tracks_for(self, uri: str) -> list[dict]:
        """All tracks behind a senada:<kind>:<id> context URI."""
        parts = (uri or "").split(":", 2)
        if len(parts) < 3 or parts[0] != "senada":
            return []
        kind, cid = parts[1], parts[2]
        page = self.load(kind, cid)
        if kind == "artist" and page.get("songsPlaylist"):
            try:
                return self.load("playlist", page["songsPlaylist"]).get("tracks") or page.get("tracks") or []
            except (ytmusic.YTMusicError, LookupError):
                pass
        return page.get("tracks") or []

    def card_for(self, page: dict) -> dict:
        keep = ("kind", "id", "uri", "name", "subtitle", "imageSmall", "image", "imageLarge")
        return {k: page.get(k, "") for k in keep}
