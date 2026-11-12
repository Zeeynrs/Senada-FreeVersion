"""Read public Spotify playlists, albums and tracks without any Spotify account.

The public embed page (open.spotify.com/embed/...) gives the name, the first ~100 tracks
and an anonymous access token. With that token the rest of a playlist is read page by
page, first through the query API the Spotify web player itself uses (works for every
public playlist, including Spotify's own editorial ones, and includes covers), else
through the public Web API (user playlists only). If both fail, the first 100 remain.

Imported tracks keep their Spotify URI plus title/artist/album/duration/cover; the
resolver finds the matching audio on YouTube Music when they are played.
"""

import json
import logging
import re
import urllib.error
import urllib.request

from . import net
from .config import CACHE_DIR, read_json, write_private

logger = logging.getLogger("senada.spotify")

PAGE = 100
MAX_TRACKS = 10_000  # Spotify's own playlist limit
PARTNER_URL = "https://api-partner.spotify.com/pathfinder/v2/query"
# persisted-query id of the web player's "fetchPlaylist"; refreshed from the web player
# script automatically when Spotify changes it
DEFAULT_PLAYLIST_HASH = "21ea11a6ac75a5f3e01fd365d29c18e0a4a8b7dc09f89bbb5d73910190c6acaf"
HASH_CACHE = CACHE_DIR / "spotify-query.json"

LINK_RE = re.compile(r"(?:open\.spotify\.com/(?:intl-[a-z]+/)?(?:embed/)?|spotify:)(playlist|album|track)[/:]([A-Za-z0-9]{22})")
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"


class SpotifyImportError(Exception):
    pass


def parse_link(text: str) -> tuple[str, str] | None:
    """('playlist' | 'album' | 'track', id) from a Spotify link or URI."""
    m = LINK_RE.search(text or "")
    return (m.group(1), m.group(2)) if m else None


def _artists(value) -> str:
    if isinstance(value, list):
        return ", ".join(a.get("name", "") for a in value if isinstance(a, dict))
    return re.sub(r"\s*,\s*", ", ", (value or "").replace(" ", " ")).strip()


def _entity(kind: str, sid: str) -> tuple[dict, str]:
    """(entity, anonymous access token) from the embed page."""
    req = urllib.request.Request(f"https://open.spotify.com/embed/{kind}/{sid}", headers={"User-Agent": USER_AGENT})
    try:
        with net.urlopen(req, timeout=10) as resp:
            html = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raise SpotifyImportError("Spotify tidak menemukan link ini (pastikan playlist-nya publik)."
                                 if e.code == 404 else f"Spotify menolak permintaan (HTTP {e.code}).") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise SpotifyImportError(f"Tidak bisa menghubungi Spotify: {getattr(e, 'reason', e)}") from e
    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
    if not m:
        raise SpotifyImportError("Format halaman Spotify berubah; impor belum bisa dibaca.")
    try:
        data = json.loads(m.group(1))
    except ValueError as e:
        raise SpotifyImportError("Data Spotify tidak bisa dibaca.") from e
    state = ((data.get("props") or {}).get("pageProps") or {}).get("state") or {}
    entity = (state.get("data") or {}).get("entity") or {}
    if not entity.get("name") and not entity.get("title"):
        raise SpotifyImportError("Spotify tidak menemukan link ini (pastikan playlist-nya publik).")
    token = ((state.get("settings") or {}).get("session") or {}).get("accessToken") or ""
    return entity, token


# ---- the rest of a playlist ------------------------------------------------------------

def _request_json(url: str, token: str, body: dict | None = None):
    headers = {"User-Agent": USER_AGENT, "Authorization": "Bearer " + token, "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers.update({"Content-Type": "application/json;charset=UTF-8", "App-Platform": "WebPlayer"})
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if body is not None else "GET")
    with net.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def _scrape_playlist_hash() -> str:
    """Current "fetchPlaylist" query id, read from the web player's script."""
    req = urllib.request.Request("https://open.spotify.com/", headers={"User-Agent": USER_AGENT})
    with net.urlopen(req, timeout=15) as resp:
        html = resp.read().decode("utf-8", "replace")
    scripts = re.findall(r'https://[a-z.]*spotifycdn\.com/cdn/build/web-player/[^"]+\.js', html)
    scripts.sort(key=lambda u: "/web-player/web-player." not in u)  # the main bundle first
    for src in scripts:
        try:
            with net.urlopen(urllib.request.Request(src, headers={"User-Agent": USER_AGENT}), timeout=20) as resp:
                m = re.search(r'"fetchPlaylist","query","([0-9a-f]{64})"', resp.read().decode("utf-8", "replace"))
        except (urllib.error.URLError, TimeoutError, OSError):
            continue
        if m:
            return m.group(1)
    raise SpotifyImportError("query id not found")


def _playlist_hash(refresh: bool = False) -> str:
    if not refresh:
        return read_json(HASH_CACHE).get("fetchPlaylist") or DEFAULT_PLAYLIST_HASH
    h = _scrape_playlist_hash()
    write_private(HASH_CACHE, {"fetchPlaylist": h})
    return h


def _cover(sources: list) -> dict:
    """imageSmall / image / imageLarge from a list of {url, width} sources."""
    by_width = sorted((s for s in sources or [] if s.get("url")), key=lambda s: s.get("width") or 0)
    if not by_width:
        return {}
    pick = lambda w: next((s["url"] for s in by_width if (s.get("width") or 0) >= w), by_width[-1]["url"])  # noqa: E731
    return {"imageSmall": pick(64), "image": pick(300), "imageLarge": by_width[-1]["url"]}


def _partner_track(d: dict) -> dict | None:
    uri = d.get("uri") or ""
    if d.get("__typename") != "Track" or not uri.startswith("spotify:track:"):
        return None  # podcast episodes, local files, removed tracks
    album = d.get("albumOfTrack") or {}
    return {
        "uri": uri,
        "id": uri.rsplit(":", 1)[-1],
        "name": d.get("name") or "",
        "artists": ", ".join(a.get("profile", {}).get("name", "") for a in (d.get("artists") or {}).get("items", [])),
        "artistId": "",
        "album": album.get("name") or "",
        "albumId": "",
        "imageSmall": "", "image": "", "imageLarge": "",
        **_cover((album.get("coverArt") or {}).get("sources")),
        "durationMs": int((d.get("trackDuration") or {}).get("totalMilliseconds") or 0),
        "explicit": (d.get("contentRating") or {}).get("label") == "EXPLICIT",
        "playable": (d.get("playability") or {}).get("playable", True) is not False,
    }


def _partner_playlist(sid: str, token: str) -> tuple[dict, list[dict]]:
    """(playlist info, every track) through the web player's query API."""
    query_hash = _playlist_hash()
    refreshed = False
    info, tracks, offset, total = {}, [], 0, None
    while offset < MAX_TRACKS and (total is None or offset < total):
        body = {"operationName": "fetchPlaylist",
                "variables": {"uri": f"spotify:playlist:{sid}", "offset": offset, "limit": PAGE,
                              "enableWatchFeedEntrypoint": False},
                "extensions": {"persistedQuery": {"version": 1, "sha256Hash": query_hash}}}
        try:
            data = _request_json(PARTNER_URL, token, body)
        except urllib.error.HTTPError as e:
            if e.code in (400, 412) and not refreshed:  # Spotify rotated the query id
                query_hash, refreshed = _playlist_hash(refresh=True), True
                continue
            raise
        playlist = (data.get("data") or {}).get("playlistV2") or {}
        content = playlist.get("content") or {}
        items = content.get("items") or []
        if not info:
            info = playlist
        total = content.get("totalCount") or 0
        tracks += [t for t in (_partner_track(((i.get("itemV2") or {}).get("data")) or {}) for i in items) if t]
        if not items:
            break
        offset += len(items)
    return info, tracks


def _webapi_tracks(sid: str, token: str, offset: int) -> list[dict]:
    """Tracks from `offset` on through the public Web API (user playlists only)."""
    fields = "total,next,items(track(type,uri,name,duration_ms,explicit,artists(name),album(name,images)))"
    url = f"https://api.spotify.com/v1/playlists/{sid}/tracks?offset={offset}&limit={PAGE}&fields={fields}"
    out = []
    while url and offset + len(out) < MAX_TRACKS:
        data = _request_json(url, token)
        for item in data.get("items") or []:
            t = item.get("track") or {}
            if t.get("type") != "track" or not (t.get("uri") or "").startswith("spotify:track:"):
                continue
            album = t.get("album") or {}
            out.append({
                "uri": t["uri"], "id": t["uri"].rsplit(":", 1)[-1], "name": t.get("name") or "",
                "artists": ", ".join(a.get("name", "") for a in t.get("artists") or []),
                "artistId": "", "album": album.get("name") or "", "albumId": "",
                "imageSmall": "", "image": "", "imageLarge": "",
                **_cover(album.get("images")),
                "durationMs": int(t.get("duration_ms") or 0), "explicit": bool(t.get("explicit")), "playable": True,
            })
        url = data.get("next")
    return out


def _full_playlist(sid: str, token: str, first: list[dict]) -> tuple[dict, list[dict], bool]:
    """(info, tracks, complete). Falls back step by step and never loses the first page."""
    if token:
        try:
            info, tracks = _partner_playlist(sid, token)
            if tracks:
                return info, tracks, True
        except (urllib.error.URLError, TimeoutError, OSError, ValueError, SpotifyImportError) as e:
            logger.info("Spotify query API failed for %s: %s", sid, e)
        if len(first) >= PAGE:
            try:
                return {}, first + _webapi_tracks(sid, token, len(first)), True
            except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
                logger.info("Spotify Web API failed for %s: %s", sid, e)
    return {}, first, len(first) < PAGE


def _dedupe(tracks: list[dict]) -> list[dict]:
    seen, out = set(), []
    for t in tracks:
        if t["uri"] not in seen:
            seen.add(t["uri"])
            out.append(t)
    return out


def _track(t: dict, album: str = "", album_artists: str = "") -> dict | None:
    uri = t.get("uri") or ""
    if not uri.startswith("spotify:track:"):
        return None
    return {
        "uri": uri,
        "id": uri.rsplit(":", 1)[-1],
        "name": t.get("title") or t.get("name") or "",
        "artists": _artists(t.get("subtitle") or t.get("artists")) or album_artists,
        "artistId": "",
        "album": album,
        "albumId": "",
        "imageSmall": "",
        "image": "",
        "imageLarge": "",
        "durationMs": int(t.get("duration") or 0),
        "explicit": bool(t.get("isExplicit")),
        "playable": t.get("isPlayable", True) is not False,
    }


def fetch(kind: str, sid: str) -> dict:
    """Collection dict (same shape as the catalog pages) for a public Spotify item."""
    entity, token = _entity(kind, sid)
    name = entity.get("name") or entity.get("title") or "Spotify"
    info, complete, cover = {}, True, {}
    if kind == "track":
        t = _track({**entity, "uri": entity.get("uri") or f"spotify:track:{sid}"})
        tracks = [t] if t else []
        subtitle = t["artists"] if t else ""
    else:
        subtitle = _artists(entity.get("subtitle"))
        album = name if kind == "album" else ""
        tracks = [x for x in (_track(t, album, subtitle if kind == "album" else "") for t in entity.get("trackList") or []) if x]
        if kind == "playlist":
            info, tracks, complete = _full_playlist(sid, token, tracks)
            tracks = _dedupe(tracks)
            cover = _cover(((info.get("images") or {}).get("items") or [{}])[0].get("sources"))
            if not cover:  # Spotify's own playlists have no public cover: use the first song's art
                first = next((t for t in tracks if t.get("image")), None)
                if first:
                    cover = {k: first[k] for k in ("imageSmall", "image", "imageLarge")}
    cid = f"sp-{sid}"
    return {
        "kind": "album" if kind == "album" else "playlist",
        "id": cid,
        "uri": f"senada:{'album' if kind == 'album' else 'playlist'}:{cid}",
        "name": name,
        "typeLabel": "Album Spotify" if kind == "album" else "Playlist Spotify",
        "subtitle": subtitle or "Spotify",
        "description": re.sub(r"<[^>]+>", "", info.get("description") or ""),
        "imageSmall": cover.get("imageSmall", ""),
        "image": cover.get("image", ""),
        "imageLarge": cover.get("imageLarge", ""),
        "tracks": tracks,
        "note": ("Playlist ini kosong atau tidak publik." if not tracks
                 else f"Dibaca dari Spotify: {len(tracks)} lagu. Audio dicari otomatis di YouTube Music." if complete
                 else f"Hanya {len(tracks)} lagu pertama yang bisa dibaca dari Spotify saat ini. "
                      "Audio dicari otomatis di YouTube Music."),
        "source": f"https://open.spotify.com/{kind}/{sid}",
    }
