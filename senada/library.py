"""Library browsing for QML: home, collections, search and the local library.

The catalog comes from YouTube Music (no account); liked songs, own playlists,
saved albums/playlists and history are stored locally.
"""

import re
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import matching, spotify_import, ytmusic
from .catalog import Catalog
from .i18n import tr, trn
from .store import LocalStore

YT_LINK_RE = re.compile(r"(?:music\.)?youtube\.com/|youtu\.be/")
YT_IMPORT_LIMIT = 5000  # YouTube's own playlist limit
# lists that only exist for a signed-in account: Liked Music, Liked videos, Watch later, Episodes
YT_ACCOUNT_LISTS = ("LM", "LL", "WL", "SE")


class ImportLinkError(Exception):
    pass


def _yt_link(text: str, list_first: bool = False) -> tuple[str, str] | None:
    """(kind, id) for a YouTube / YouTube Music link. `list_first`: a song played from a
    playlist (watch?v=…&list=…) stands for the playlist (for importing)."""
    if not YT_LINK_RE.search(text):
        return None
    url = urllib.parse.urlparse(text if "://" in text else "https://" + text)
    q = urllib.parse.parse_qs(url.query)
    if list_first and q.get("list"):
        return "playlist", q["list"][0]
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


def youtube_collection(kind: str, cid: str) -> dict:
    """A public or unlisted YouTube Music / YouTube playlist (or album) ready to import."""
    if cid.upper() in YT_ACCOUNT_LISTS:
        raise ImportLinkError(tr("Liked songs and other lists of your YouTube account need a login, which Senada does not use. "
                                 "Copy the songs into a playlist, make it public or unlisted, and import that link."))
    if cid.startswith("RD") and not cid.startswith("RDCLAK"):  # mixes are made for each listener (RDCLAK = editorial)
        raise ImportLinkError(tr("A YouTube mix cannot be imported: it changes for every listener. Save it as a playlist first."))
    unreachable = tr("YouTube Music could not open this playlist (make sure it is public or unlisted).")
    try:
        page = ytmusic.album(cid) if kind == "album" else ytmusic.playlist(cid, limit=YT_IMPORT_LIMIT)
    except ytmusic.YTMusicError as e:
        if "HTTP" in str(e):
            raise ImportLinkError(unreachable) from e
        raise
    if not page.get("tracks"):
        raise ImportLinkError(unreachable)
    source = (f"https://music.youtube.com/browse/{cid}" if kind == "album"
              else f"https://music.youtube.com/playlist?list={cid}")
    return {**page, "source": source}


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
    matchCandidatesReady = Signal(str, "QVariantList")  # uri, scored YouTube Music candidates
    toast = Signal(str)

    def __init__(self, store: LocalStore, catalog: Catalog, worker, session, player=None, resolver=None, parent=None):
        super().__init__(parent)
        self.resolver = resolver
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
            player.trackMatched.connect(self._on_track_matched)
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

    @Property(int, constant=True)
    def matchThreshold(self):
        """Imported tracks matched below this score get a "check me" badge."""
        return matching.ACCEPT

    @Property(int, notify=likedChanged)
    def likedRevision(self):
        return self._liked_rev

    @Property(int, notify=likedChanged)
    def likedCount(self):
        return len(self.store.liked())

    @Property("QVariantList", notify=likedChanged)
    def likedPreview(self):
        """The most recently liked songs, for the home page."""
        tracks = self.store.liked()[:6]
        self._cache(tracks)
        return tracks

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
                        "subtitle": tr("My playlist") + " • " + trn("{n} song", "{n} songs", p["count"]), "count": p["count"], "local": True,
                        "imported": bool(p.get("source")),
                        "imageSmall": cover.get("imageSmall", ""), "image": cover.get("image", ""),
                        "imageLarge": cover.get("imageLarge", "")})
        saved = []
        for s in self.store.saved():
            label = {"album": tr("Album"), "playlist": tr("Playlist"), "artist": tr("Artist")}.get(s["kind"], "")
            sub = s.get("subtitle", "")
            saved.append({**s, "subtitle": " • ".join(x for x in (label, sub if sub != label else "") if x)})
        self._own = own
        self._playlists = own + saved
        self.playlistsChanged.emit()

    def _refresh_recent(self):
        self._recent = self.store.history(12)
        self._cache(self._recent)  # so "Lanjut dengar" can replay them after a restart
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
            self.toast.emit(tr("Saved to Library") if now else tr("Removed from Library"))

    # ---- own playlists ----------------------------------------------------------

    @Slot(str, "QVariantList", result=str)
    def createPlaylist(self, name, tracks):
        pid = self.store.create_playlist(name, [dict(t) for t in tracks or []])
        self._refresh_playlists()
        self.toast.emit(tr("Playlist “{name}” created", name=(name or "").strip() or tr("New playlist")))
        return pid

    @Slot(str, str)
    def renamePlaylist(self, pid, name):
        if self.store.rename_playlist(pid, name):
            self._refresh_playlists()

    @Slot(str)
    def deletePlaylist(self, pid):
        if self.store.delete_playlist(pid):
            self._refresh_playlists()
            self.toast.emit(tr("Playlist deleted"))

    @Slot(str, "QVariantList")
    def addToPlaylist(self, pid, tracks):
        added = self.store.add_to_playlist(pid, [dict(t) for t in tracks or []])
        self._refresh_playlists()
        name = next((p["name"] for p in self._own if p["id"] == pid), "playlist")
        self.toast.emit(tr("Added to “{name}”", name=name) if added else tr("Already in “{name}”", name=name))

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
            self.toast.emit(tr("No songs to import"))
            return
        name = info.get("name") or tr("Import")
        pid = self.store.create_playlist(name, tracks, source=info.get("source", ""),
                                         description=info.get("description", ""))
        self._refresh_playlists()
        self.toast.emit(trn("{n} song imported into “{name}”", "{n} songs imported into “{name}”", len(tracks), name=name))
        self.playlistCreated.emit(pid)
        self.matchTracks(tracks)

    # ---- matching imported tracks to YouTube Music --------------------------------

    def _store_patches(self, patches: dict):
        if patches and self.store.patch_tracks(patches):
            self._refresh_playlists()
            self._refresh_recent()
            self._bump_liked()

    def _on_track_matched(self, uri, patch):
        self._store_patches({uri: dict(patch)})

    @staticmethod
    def _patch_from(info: dict) -> dict:
        patch = {k: info.get(k) for k in ("imageSmall", "image", "imageLarge") if info.get(k)}
        patch["matchScore"] = info.get("s", 0)
        return patch

    @Slot("QVariantList")
    def matchTracks(self, tracks):
        """Match metadata-only tracks (Spotify imports) in the background and fill in their covers."""
        if self.resolver is None:
            return
        todo = [dict(t) for t in tracks or [] if not (t.get("uri") or "").startswith("yt:track:")]
        if not todo:
            return
        self.toast.emit(trn("Matching {n} song with YouTube Music…", "Matching {n} songs with YouTube Music…", len(todo)))

        def safe_match(t):
            try:
                return self.resolver.match(t)
            except Exception:  # one bad lookup must not stop the batch
                return None

        def job():
            with ThreadPoolExecutor(max_workers=4, thread_name_prefix="senada-match") as pool:
                results = list(pool.map(safe_match, todo))
            patches, weak, missing = {}, 0, 0
            for t, info in zip(todo, results):
                if not info:
                    missing += 1
                    continue
                patches[t["uri"]] = self._patch_from(info)
                weak += info.get("s", 0) < matching.ACCEPT
            return patches, weak, missing

        def done(result):
            patches, weak, missing = result
            self._store_patches(patches)
            parts = [tr("{n} matched", n=len(patches) - weak)]
            if weak:
                parts.append(tr("{n} unsure", n=weak))
            if missing:
                parts.append(tr("{n} not found", n=missing))
            hint = tr(" — check the songs marked ? (right-click → Pick another version)") if weak or missing else ""
            self.toast.emit(tr("Matching done: {result}", result=", ".join(parts)) + hint)

        self.worker.run(job, done, lambda e: self.toast.emit(tr("Matching failed: {error}", error=e)))

    @Slot("QVariantMap")
    def matchCandidates(self, track):
        """Every YouTube Music candidate for a track, scored (for the "Pilih versi lain…" picker)."""
        track = dict(track)
        uri = track.get("uri", "")

        def job():
            current = (self.resolver.cached(uri) or {}).get("v") if self.resolver else None
            out = []
            for c in (self.resolver.candidates(track, thorough=True) if self.resolver else [])[:12]:
                m = c.pop("match")
                out.append({**c, "score": m["score"], "tags": m["tags"], "current": c["id"] == current,
                            "deltaMs": (c.get("durationMs") or 0) - (track.get("durationMs") or 0)
                            if c.get("durationMs") and track.get("durationMs") else None})
            return out

        self.worker.run(job, lambda cands: self.matchCandidatesReady.emit(uri, cands),
                        lambda e: self.matchCandidatesReady.emit(uri, []))

    @Slot("QVariantMap", "QVariantMap")
    def chooseMatch(self, track, cand):
        """Use this YouTube Music upload for the track from now on."""
        if self.resolver is None:
            return
        track, cand = dict(track), dict(cand)
        info = self.resolver.choose(track, cand)
        patch = self._patch_from(info)
        self._store_patches({track["uri"]: patch})
        if self.player is not None:
            self.player.replaceMatch(track["uri"], patch)
        self.toast.emit(tr("Using “{name}” for this song", name=cand.get("name", "")))

    @Slot(str)
    def importLink(self, link):
        """Copy a public playlist or album from Spotify or YouTube Music into a new own playlist."""
        link = (link or "").strip()
        sp = spotify_import.parse_link(link)
        yt = None if sp else _yt_link(link, list_first=True)
        if sp and sp[0] != "track":
            self.toast.emit(tr("Reading the Spotify playlist…"))
            fetch = lambda: spotify_import.fetch(*sp)  # noqa: E731
        elif yt and yt[0] in ("playlist", "album"):
            self.toast.emit(tr("Reading the YouTube Music playlist…"))
            fetch = lambda: youtube_collection(*yt)  # noqa: E731
        else:
            self.toast.emit(tr("Paste a link to a playlist or album from Spotify or YouTube Music"))
            return
        self.worker.run(fetch, self.importCollection, lambda e: self.toast.emit(str(e)))
