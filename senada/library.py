"""Library browsing for QML: home, collections, search and the local library.

The catalog comes from YouTube Music (no account); liked songs, own playlists,
saved albums/playlists and history are stored locally.
"""

import re
import urllib.parse

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import spotify_import, ytmusic
from .catalog import Catalog
from .store import LocalStore

YT_LINK_RE = re.compile(r"(?:music\.)?youtube\.com/|youtu\.be/")


def _yt_link(text: str) -> tuple[str, str] | None:
    """(kind, id) for a YouTube / YouTube Music link."""
    if not YT_LINK_RE.search(text):
        return None
    url = urllib.parse.urlparse(text if "://" in text else "https://" + text)
    q = urllib.parse.parse_qs(url.query)
    if url.netloc.endswith("youtu.be"):
        return ("track", url.path.strip("/")) if url.path.strip("/") else None
    if url.path.startswith("/watch") and q.get("v"):
        return "track", q["v"][0]
    if q.get("list"):
        return "playlist", q["list"][0]
    m = re.match(r"/browse/(MPREb_[\w-]+)", url.path)
    if m:
        return "album", m.group(1)
    m = re.match(r"/channel/(UC[\w-]+)", url.path)
    if m:
        return "artist", m.group(1)
    return None


class Library(QObject):
    meChanged = Signal()
    playlistsChanged = Signal()
    homeChanged = Signal()
    recentChanged = Signal()
    likedChanged = Signal()
    savedChanged = Signal()
    loaded = Signal(str, "QVariantMap")  # page key, data
    searchFinished = Signal(str, "QVariantMap")  # query, results
    playlistCreated = Signal(str)  # new playlist id (e.g. after an import)
    toast = Signal(str)

    def __init__(self, store: LocalStore, catalog: Catalog, worker, session, player=None, parent=None):
        super().__init__(parent)
        self.store = store
        self.catalog = catalog
        self.worker = worker
        self.session = session
        self.player = player
        self._home = {"sections": [], "loading": True, "error": ""}
        self._recent = store.history(12)
        self._playlists = []
        self._own = []
        self._liked_rev = 0
        self._saved_rev = 0
        session.changed.connect(self.meChanged)
        if player is not None:
            player.likedChanged.connect(lambda *_: self._bump_liked())
            player.historyChanged.connect(self._refresh_recent)
        self._refresh_playlists()

    # ---- properties --------------------------------------------------------

    @Property("QVariantMap", notify=meChanged)
    def me(self):
        return {"id": "local", "name": self.session.displayName, "image": ""}

    @Property("QVariantList", notify=playlistsChanged)
    def playlists(self):
        """Sidebar entries: own playlists, then saved albums/playlists."""
        return self._playlists

    @Property("QVariantList", notify=playlistsChanged)
    def ownPlaylists(self):
        return self._own

    @Property("QVariantMap", notify=homeChanged)
    def home(self):
        return self._home

    @Property("QVariantList", notify=recentChanged)
    def recent(self):
        """Recently played tracks (kept apart from `home` so a track change doesn't rebuild the shelves)."""
        return self._recent

    @Property(int, notify=likedChanged)
    def likedRevision(self):
        return self._liked_rev

    @Property(int, notify=savedChanged)
    def savedRevision(self):
        return self._saved_rev

    # ---- internal ----------------------------------------------------------

    def _bump_liked(self):
        self._liked_rev += 1
        self.likedChanged.emit()

    def _refresh_playlists(self):
        own = []
        for p in self.store.playlists():
            full = self.store.playlist(p["id"]) or {}
            cover = next((t for t in full.get("tracks", []) if t.get("imageSmall")), {})
            own.append({"kind": "playlist", "id": p["id"], "uri": f"senada:playlist:{p['id']}", "name": p["name"],
                        "subtitle": f"Playlist Saya • {p['count']} lagu", "count": p["count"], "local": True,
                        "imageSmall": cover.get("imageSmall", ""), "image": cover.get("image", ""),
                        "imageLarge": cover.get("imageLarge", "")})
        saved = []
        for s in self.store.saved():
            label = {"album": "Album", "playlist": "Playlist", "artist": "Artis"}.get(s["kind"], "")
            saved.append({**s, "subtitle": " • ".join(x for x in (label, s.get("subtitle", "")) if x)})
        self._own = own
        self._playlists = own + saved
        self.playlistsChanged.emit()

    def _refresh_recent(self):
        self._recent = self.store.history(12)
        self.recentChanged.emit()

    def _cache(self, tracks):
        if self.player is not None:
            self.player.cache_tracks(tracks or [])

    # ---- home ----------------------------------------------------------------

    @Slot()
    def refreshAll(self):
        self._refresh_playlists()
        self._refresh_recent()
        self._home = {**self._home, "loading": True, "error": ""}
        self.homeChanged.emit()
        self.meChanged.emit()

        def ok(sections):
            for s in sections:
                self._cache(s.get("tracks"))
            self._home = {**self._home, "sections": sections, "loading": False, "error": ""}
            self.homeChanged.emit()

        def fail(e):
            self._home = {**self._home, "loading": False, "error": str(e)}
            self.homeChanged.emit()

        self.worker.run(ytmusic.home, ok, fail)

    # ---- pages ---------------------------------------------------------------

    @Slot(str, str)
    def load(self, kind, item_id):
        key = f"{kind}:{item_id}"

        def on_done(data):
            if isinstance(data, dict):
                self._cache(data.get("tracks"))
                data = {**data, "saved": self.store.is_saved(data.get("kind", kind), data.get("id", item_id))}
            self.loaded.emit(key, data)

        self.worker.run(lambda: self.catalog.load(kind, item_id), on_done,
                        lambda e: self.loaded.emit(key, {"error": str(e)}))

    # ---- search --------------------------------------------------------------

    @Slot(str)
    def search(self, query):
        query = query.strip()
        if not query:
            return
        empty = {"tracks": [], "artists": [], "albums": [], "playlists": []}

        def fetch():
            sp = spotify_import.parse_link(query)
            if sp:
                kind, sid = sp
                page = spotify_import.fetch(kind, sid)
                if kind == "track":
                    t = page["tracks"][0] if page["tracks"] else None
                    return ytmusic.search(f"{t['artists']} {t['name']}") if t else empty
                key = "albums" if kind == "album" else "playlists"
                return {**empty, "tracks": page["tracks"], key: [self.catalog.card_for(page)]}
            yt = _yt_link(query)
            if yt:
                kind, cid = yt
                if kind == "track":
                    t = ytmusic.track(cid)
                    return {**empty, "tracks": [t] if t else []}
                page = self.catalog.load(kind, cid)
                return {**empty, "tracks": page.get("tracks", [])[:50], kind + "s": [self.catalog.card_for(page)]}
            return ytmusic.search(query)

        def on_done(r):
            if isinstance(r, dict):
                self._cache(r.get("tracks"))
            self.searchFinished.emit(query, r)

        self.worker.run(fetch, on_done, lambda e: self.searchFinished.emit(query, {"error": str(e)}))

    # ---- liked / saved --------------------------------------------------------

    @Slot(str, result=bool)
    def isLiked(self, uri):
        return self.store.is_liked(uri)

    @Slot(str, str, result=bool)
    def isSaved(self, kind, item_id):
        return self.store.is_saved(kind, item_id)

    @Slot("QVariantMap")
    def toggleSaved(self, info):
        info = dict(info)
        kind, cid = info.get("kind", ""), info.get("id", "")
        if not kind or not cid or cid.startswith("local-"):
            return
        if cid.startswith("sp-"):
            self.importCollection(info)
            return
        now = not self.store.is_saved(kind, cid)
        if self.store.set_saved(self.catalog.card_for(info), now):
            self._saved_rev += 1
            self.savedChanged.emit()
            self._refresh_playlists()
            self.toast.emit("Disimpan ke Library" if now else "Dihapus dari Library")

    # ---- own playlists ----------------------------------------------------------

    @Slot(str, "QVariantList", result=str)
    def createPlaylist(self, name, tracks):
        pid = self.store.create_playlist(name, [dict(t) for t in tracks or []])
        self._refresh_playlists()
        self.toast.emit(f"Playlist “{(name or '').strip() or 'Playlist baru'}” dibuat")
        return pid

    @Slot(str, str)
    def renamePlaylist(self, pid, name):
        if self.store.rename_playlist(pid, name):
            self._refresh_playlists()

    @Slot(str)
    def deletePlaylist(self, pid):
        if self.store.delete_playlist(pid):
            self._refresh_playlists()
            self.toast.emit("Playlist dihapus")

    @Slot(str, "QVariantList")
    def addToPlaylist(self, pid, tracks):
        added = self.store.add_to_playlist(pid, [dict(t) for t in tracks or []])
        self._refresh_playlists()
        name = next((p["name"] for p in self._own if p["id"] == pid), "playlist")
        self.toast.emit(f"Ditambahkan ke “{name}”" if added else f"Sudah ada di “{name}”")

    @Slot(str, str)
    def removeFromPlaylist(self, pid, uri):
        if self.store.remove_from_playlist(pid, uri):
            self._refresh_playlists()

    @Slot("QVariantMap")
    def importCollection(self, info):
        """Copy a (Spotify) playlist/album page into a new own playlist."""
        info = dict(info)
        tracks = [dict(t) for t in info.get("tracks") or []]
        if not tracks:
            self.toast.emit("Tidak ada lagu untuk diimpor")
            return
        pid = self.store.create_playlist(info.get("name") or "Impor", tracks, source=info.get("source", ""),
                                         description=info.get("description", ""))
        self._refresh_playlists()
        self.toast.emit(f"{len(tracks)} lagu diimpor ke “{info.get('name') or 'Impor'}”")
        self.playlistCreated.emit(pid)

    @Slot(str)
    def importSpotify(self, link):
        parsed = spotify_import.parse_link(link)
        if not parsed or parsed[0] == "track":
            self.toast.emit("Tempel link playlist atau album Spotify (open.spotify.com/playlist/…)")
            return
        self.toast.emit("Membaca playlist Spotify…")
        self.worker.run(lambda: spotify_import.fetch(*parsed), self.importCollection,
                        lambda e: self.toast.emit(str(e)))
