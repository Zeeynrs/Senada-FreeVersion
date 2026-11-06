"""Library browsing: home, playlists, albums, artists, liked songs and search."""

import json
import re
import urllib.request
from PySide6.QtCore import Property, QObject, Signal, Slot

from . import api as sp
from .api import ApiError

FEATURED_PLAYLISTS = [
    {
        "kind": "playlist",
        "id": "37i9dQZF1DXcBWIGoYBM5M",
        "uri": "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M",
        "name": "Today's Top Hits",
        "subtitle": "Spotify • Top Hits Populer",
        "image": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b1f1f2382f6e91f1a5cc6322",
        "imageSmall": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b1f1f2382f6e91f1a5cc6322",
        "imageLarge": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b1f1f2382f6e91f1a5cc6322",
        "count": 50,
    },
    {
        "kind": "playlist",
        "id": "37i9dQZF1DX0XUsuxWHRQd",
        "uri": "spotify:playlist:37i9dQZF1DX0XUsuxWHRQd",
        "name": "RapCaviar",
        "subtitle": "Spotify • Hip-Hop",
        "image": "https://image-cdn-ak.spotifycdn.com/image/ab67706f0000000282b04f378000be087c53e8a4",
        "imageSmall": "https://image-cdn-ak.spotifycdn.com/image/ab67706f0000000282b04f378000be087c53e8a4",
        "imageLarge": "https://image-cdn-ak.spotifycdn.com/image/ab67706f0000000282b04f378000be087c53e8a4",
        "count": 50,
    },
    {
        "kind": "playlist",
        "id": "37i9dQZF1DX4WYpdgoIcn6",
        "uri": "spotify:playlist:37i9dQZF1DX4WYpdgoIcn6",
        "name": "Chill Hits",
        "subtitle": "Spotify • Santai",
        "image": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b60db5d104fa3e3d808013f4",
        "imageSmall": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b60db5d104fa3e3d808013f4",
        "imageLarge": "https://image-cdn-ak.spotifycdn.com/image/ab67706f00000002b60db5d104fa3e3d808013f4",
        "count": 50,
    },
]


def fetch_public_playlist_embed(pid: str) -> dict | None:
    url = f"https://open.spotify.com/embed/playlist/{pid}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            html = resp.read().decode("utf-8")
        m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html)
        if not m:
            return None
        data = json.loads(m.group(1))
        entity = data.get("props", {}).get("pageProps", {}).get("state", {}).get("data", {}).get("entity", {})
        tracks = []
        for t in entity.get("trackList", []):
            tracks.append({
                "uri": t.get("uri", ""),
                "id": t.get("uri", "").split(":")[-1],
                "name": t.get("title", ""),
                "artists": t.get("subtitle", ""),
                "artistId": "",
                "album": entity.get("name", ""),
                "albumId": pid,
                "imageSmall": "",
                "image": "",
                "imageLarge": "",
                "durationMs": t.get("duration", 0),
                "explicit": bool(t.get("isExplicit")),
                "playable": True,
            })
        return {
            "kind": "playlist",
            "id": pid,
            "uri": f"spotify:playlist:{pid}",
            "name": entity.get("name", "Playlist Publik"),
            "typeLabel": "Playlist Publik",
            "subtitle": f"{len(tracks)} lagu",
            "ownerId": "",
            "description": entity.get("subtitle", ""),
            "count": len(tracks),
            "imageSmall": "",
            "image": "",
            "imageLarge": "",
            "tracks": tracks,
            "note": "Dimuat melalui mode publik tanpa akun.",
            "playUri": f"spotify:playlist:{pid}",
        }
    except Exception:
        return None


class Library(QObject):
    meChanged = Signal()
    playlistsChanged = Signal()
    homeChanged = Signal()
    loaded = Signal(str, "QVariantMap")  # page key, data
    searchFinished = Signal(str, "QVariantMap")  # query, results

    def __init__(self, api: sp.SpotifyApi, worker, player=None, resolver=None, parent=None):
        super().__init__(parent)
        self.api = api
        self.worker = worker
        self.player = player
        self.resolver = resolver
        self._me = {}
        self._playlists = []
        self._home = {}

    @Property("QVariantMap", notify=meChanged)
    def me(self):
        return self._me

    @Property("QVariantList", notify=playlistsChanged)
    def playlists(self):
        return self._playlists

    @Property("QVariantMap", notify=homeChanged)
    def home(self):
        return self._home

    @Slot()
    def refreshAll(self):
        self.worker.run(self._fetch_me, self._set_me)
        if self.api.tokens.has_tokens:
            self.worker.run(lambda: self.api.paged("/me/playlists", max_items=500, limit=50), self._set_playlists)
        else:
            self._playlists = FEATURED_PLAYLISTS
            self.playlistsChanged.emit()
        self.worker.run(self._fetch_home, self._set_home)

    def _fetch_me(self):
        if not self.api.tokens.has_tokens:
            return {"id": "guest", "name": "Pengguna Tamu (Mode Bebas)", "image": ""}
        try:
            me = self.api.get("/me") or {}
            small, medium, _ = sp._images(me.get("images"))
            return {"id": me.get("id", ""), "name": me.get("display_name") or me.get("id", ""), "image": small}
        except Exception:
            return {"id": "guest", "name": "Pengguna Tamu (Mode Bebas)", "image": ""}

    def _set_me(self, me):
        self._me = me
        self.meChanged.emit()

    def _set_playlists(self, items):
        if items and isinstance(items[0], dict) and items[0].get("kind") == "playlist":
            self._playlists = items
        else:
            self._playlists = [sp.playlist(p) for p in items if p]
        self.playlistsChanged.emit()

    def _fetch_home(self):
        home = {"recent": [], "topTracks": [], "topArtists": []}
        if not self.api.tokens.has_tokens:
            if self.resolver:
                home["topTracks"] = self.resolver.search_tracks("Top Hits", limit=15)
            return home

        try:
            seen = set()
            for entry in (self.api.get("/me/player/recently-played", limit=50) or {}).get("items") or []:
                t = (entry.get("track") or {})
                alb = t.get("album") or {}
                if alb.get("id") and alb["id"] not in seen:
                    seen.add(alb["id"])
                    home["recent"].append(sp.album(alb))
            home["recent"] = home["recent"][:12]
        except ApiError:
            pass
        try:
            items = (self.api.get("/me/top/tracks", limit=10, time_range="short_term") or {}).get("items") or []
            home["topTracks"] = [t for t in map(sp.track, items) if t]
        except ApiError:
            if self.resolver and not home["topTracks"]:
                home["topTracks"] = self.resolver.search_tracks("Top Hits", limit=12)
        try:
            items = (self.api.get("/me/top/artists", limit=12, time_range="medium_term") or {}).get("items") or []
            home["topArtists"] = [sp.artist(a) for a in items]
        except ApiError:
            pass
        return home

    def _set_home(self, home):
        self._home = home
        if self.player:
            self.player.cache_tracks(home.get("topTracks", []))
        self.homeChanged.emit()

    # ---- pages ------------------------------------------------------------

    @Slot(str, str)
    def load(self, kind, item_id):
        key = f"{kind}:{item_id}"
        fetch = {
            "playlist": self._fetch_playlist,
            "album": self._fetch_album,
            "artist": self._fetch_artist,
            "liked": lambda _: self._fetch_liked(),
        }.get(kind)
        if not fetch:
            return

        def on_done(data):
            if self.player and isinstance(data, dict):
                self.player.cache_tracks(data.get("tracks", []))
            self.loaded.emit(key, data)

        self.worker.run(lambda: fetch(item_id),
                        on_done,
                        lambda e: self.loaded.emit(key, {"error": str(e)}))

    def _fetch_playlist(self, pid):
        if not self.api.tokens.has_tokens:
            pub = fetch_public_playlist_embed(pid)
            if pub:
                return pub
        try:
            meta = sp.playlist(self.api.get(f"/playlists/{pid}") or {})
            items = self.api.paged(f"/playlists/{pid}/items", limit=50, additional_types="track")
            tracks = [t for t in map(sp.wrapped_track, items) if t]
            return {**meta, "typeLabel": "Playlist", "tracks": tracks, "note": "", "playUri": meta["uri"]}
        except Exception:
            pub = fetch_public_playlist_embed(pid)
            if pub:
                return pub
            note = ("Spotify hanya membuka daftar lagu playlist milikmu sendiri untuk aplikasi pihak ketiga. "
                    "Playlist ini tetap bisa diputar.")
            meta = {"kind": "playlist", "id": pid, "uri": f"spotify:playlist:{pid}", "name": "Playlist",
                    "subtitle": "", "description": "", "imageSmall": "", "image": "", "imageLarge": "", "count": 0}
            return {**meta, "typeLabel": "Playlist", "tracks": [], "note": note, "playUri": meta["uri"]}

    def _fetch_album(self, aid):
        if not self.api.tokens.has_tokens:
            return {"kind": "album", "id": aid, "uri": f"spotify:album:{aid}", "name": "Album",
                    "typeLabel": "Album", "subtitle": "", "tracks": [], "playUri": f"spotify:album:{aid}"}
        a = self.api.get(f"/albums/{aid}") or {}
        meta = sp.album(a)
        items = list((a.get("tracks") or {}).get("items") or [])
        nxt = (a.get("tracks") or {}).get("next")
        while nxt:
            page = self.api.get(nxt) or {}
            items.extend(page.get("items") or [])
            nxt = page.get("next")
        tracks = [t for t in (sp.track(x, album=a) for x in items) if t]
        label = {"single": "Single", "compilation": "Kompilasi"}.get(meta["albumType"], "Album")
        sub = " • ".join(x for x in (meta["subtitle"], meta["year"], f"{len(tracks)} lagu") if x)
        return {**meta, "typeLabel": label, "subtitle": sub, "artistId": (a.get("artists") or [{}])[0].get("id", ""),
                "tracks": tracks, "playUri": meta["uri"]}

    def _fetch_artist(self, aid):
        if not self.api.tokens.has_tokens:
            return {"kind": "artist", "id": aid, "uri": f"spotify:artist:{aid}", "name": "Artis",
                    "typeLabel": "Artis", "subtitle": "", "tracks": [], "albums": [], "playUri": f"spotify:artist:{aid}"}
        a = sp.artist(self.api.get(f"/artists/{aid}") or {})
        albums = self.api.get(f"/artists/{aid}/albums", include_groups="album,single", limit=50) or {}
        popular = []
        try:
            res = self.api.get("/search", q=f'artist:"{a["name"]}"', type="track", limit=10) or {}
            popular = [t for t in map(sp.track, (res.get("tracks") or {}).get("items") or [])
                       if t and t["artistId"] == aid]
        except ApiError:
            pass
        return {**a, "tracks": popular, "albums": [sp.album(x) for x in albums.get("items") or []],
                "playUri": a["uri"]}

    def _fetch_liked(self):
        if not self.api.tokens.has_tokens:
            return {"kind": "liked", "name": "Lagu yang Disukai", "typeLabel": "Playlist",
                    "subtitle": "Mode Tamu (Login untuk menyimpan lagu)", "tracks": [], "playUri": ""}
        items = self.api.paged("/me/tracks", limit=50)
        tracks = [t for t in map(sp.wrapped_track, items) if t]
        return {"kind": "liked", "name": "Lagu yang Disukai", "typeLabel": "Playlist",
                "subtitle": f"{len(tracks)} lagu", "tracks": tracks, "playUri": ""}

    # ---- search -----------------------------------------------------------

    @Slot(str)
    def search(self, query):
        query = query.strip()
        if not query:
            return

        def fetch():
            # Check if query is a Spotify playlist link
            m_pl = re.search(r"open\.spotify\.com/playlist/([a-zA-Z0-9]+)", query)
            if m_pl:
                pub = fetch_public_playlist_embed(m_pl.group(1))
                if pub:
                    return {
                        "tracks": pub.get("tracks", []),
                        "artists": [],
                        "albums": [],
                        "playlists": [pub],
                    }

            if not self.api.tokens.has_tokens:
                if self.resolver:
                    tracks = self.resolver.search_tracks(query, limit=20)
                    return {"tracks": tracks, "artists": [], "albums": [], "playlists": []}
                return {"tracks": [], "artists": [], "albums": [], "playlists": []}

            try:
                res = self.api.get("/search", q=query, type="track,artist,album,playlist", limit=10) or {}
                pick = lambda k: [x for x in (res.get(k) or {}).get("items") or [] if x]
                return {
                    "tracks": [t for t in map(sp.track, pick("tracks")) if t],
                    "artists": [sp.artist(a) for a in pick("artists")],
                    "albums": [sp.album(a) for a in pick("albums")],
                    "playlists": [sp.playlist(p) for p in pick("playlists")],
                }
            except Exception:
                if self.resolver:
                    tracks = self.resolver.search_tracks(query, limit=20)
                    return {"tracks": tracks, "artists": [], "albums": [], "playlists": []}
                return {"tracks": [], "artists": [], "albums": [], "playlists": []}

        def on_done(r):
            if self.player and isinstance(r, dict):
                self.player.cache_tracks(r.get("tracks", []))
            self.searchFinished.emit(query, r)

        self.worker.run(fetch, on_done,
                        lambda e: self.searchFinished.emit(query, {"error": str(e)}))

