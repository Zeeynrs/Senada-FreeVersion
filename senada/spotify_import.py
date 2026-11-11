"""Read public Spotify playlists, albums and tracks without any Spotify account.

Uses the public embed pages (open.spotify.com/embed/...), which carry the track list
for up to ~100 tracks. Imported tracks keep their Spotify URI plus title/artist/duration;
the resolver finds the matching audio on YouTube Music when they are played.
"""

import json
import re
import urllib.error
import urllib.request

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


def _entity(kind: str, sid: str) -> dict:
    req = urllib.request.Request(f"https://open.spotify.com/embed/{kind}/{sid}", headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
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
    entity = (((data.get("props") or {}).get("pageProps") or {}).get("state") or {}).get("data", {}).get("entity") or {}
    if not entity.get("name") and not entity.get("title"):
        raise SpotifyImportError("Spotify tidak menemukan link ini (pastikan playlist-nya publik).")
    return entity


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
    entity = _entity(kind, sid)
    name = entity.get("name") or entity.get("title") or "Spotify"
    if kind == "track":
        t = _track({**entity, "uri": entity.get("uri") or f"spotify:track:{sid}"})
        tracks = [t] if t else []
        subtitle = t["artists"] if t else ""
    else:
        subtitle = _artists(entity.get("subtitle"))
        album = name if kind == "album" else ""
        tracks = [x for x in (_track(t, album, subtitle if kind == "album" else "") for t in entity.get("trackList") or []) if x]
    cid = f"sp-{sid}"
    return {
        "kind": "album" if kind == "album" else "playlist",
        "id": cid,
        "uri": f"senada:{'album' if kind == 'album' else 'playlist'}:{cid}",
        "name": name,
        "typeLabel": "Album Spotify" if kind == "album" else "Playlist Spotify",
        "subtitle": subtitle or "Spotify",
        "description": "",
        "imageSmall": "",
        "image": "",
        "imageLarge": "",
        "tracks": tracks,
        "note": ("Dibaca dari halaman publik Spotify (maks. ±100 lagu). Audio dicari otomatis di YouTube Music."
                 if tracks else "Playlist ini kosong atau tidak publik."),
        "source": f"https://open.spotify.com/{kind}/{sid}",
    }
