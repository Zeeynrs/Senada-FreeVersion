"""YouTube Music catalog through the public Innertube API.

Everything here works without an account: search, home/explore shelves, albums,
artists, playlists and "up next" radio. Results are normalised into the same
track/card dicts the QML pages already use.
"""

import json
import os
import re
import threading
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API_URL = "https://music.youtube.com/youtubei/v1/"
CLIENT_NAME = "WEB_REMIX"
CLIENT_VERSION = "1.20240101.01.00"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

# search filters ("params") for the music search tabs
FILTER_SONGS = "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFA%3D%3D"
FILTER_ALBUMS = "EgWKAQIYAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
FILTER_ARTISTS = "EgWKAQIgAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
FILTER_PLAYLISTS = "EgeKAQQoADgBahAQAxAEEAkQChAFEBEQEBAV"

PAGE_KINDS = {
    "MUSIC_PAGE_TYPE_ALBUM": "album",
    "MUSIC_PAGE_TYPE_AUDIOBOOK": "album",
    "MUSIC_PAGE_TYPE_ARTIST": "artist",
    "MUSIC_PAGE_TYPE_PLAYLIST": "playlist",
}
TYPE_LABELS = {"lagu", "song", "video", "episode", "episode podcast", "single", "album", "ep", "playlist", "artis", "artist"}
DURATION_RE = re.compile(r"^(\d+)[:.](\d{2})(?:[:.](\d{2}))?$")
SEPARATOR = " • "


class YTMusicError(Exception):
    pass


# Continuations only page forward when they come with the visitor id the first page
# was served to, so one id is kept for the whole session.
_visitor = ""
_visitor_lock = threading.Lock()


def region() -> tuple[str, str]:
    """(hl, gl) from the desktop locale, e.g. id_ID.UTF-8 -> ("id", "ID")."""
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        m = re.match(r"([a-z]{2})_([A-Z]{2})", os.environ.get(var, ""))
        if m:
            return m.group(1), m.group(2)
    return "id", "ID"


def _post(endpoint: str, body: dict, timeout: float = 12) -> dict:
    global _visitor
    hl, gl = region()
    client = {"clientName": CLIENT_NAME, "clientVersion": CLIENT_VERSION, "hl": hl, "gl": gl}
    headers = {"Content-Type": "application/json", "User-Agent": USER_AGENT,
               "Origin": "https://music.youtube.com", "Referer": "https://music.youtube.com/"}
    if _visitor:
        client["visitorData"] = _visitor
        headers["X-Goog-Visitor-Id"] = _visitor
    req = urllib.request.Request(
        f"{API_URL}{endpoint}?prettyPrint=false",
        data=json.dumps({"context": {"client": client}, **body}).encode(),
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
        visitor = _get(data, "responseContext", "visitorData")
        if visitor and not _visitor:
            with _visitor_lock:
                _visitor = _visitor or visitor
        return data
    except urllib.error.HTTPError as e:
        raise YTMusicError(f"YouTube Music menolak permintaan (HTTP {e.code})") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise YTMusicError(f"Tidak bisa menghubungi YouTube Music: {getattr(e, 'reason', e)}") from e
    except ValueError as e:
        raise YTMusicError("Balasan YouTube Music tidak bisa dibaca") from e


# ---- small JSON helpers ------------------------------------------------------

def _get(obj, *path, default=None):
    for key in path:
        if isinstance(obj, dict):
            obj = obj.get(key)
        elif isinstance(obj, list) and isinstance(key, int) and -len(obj) <= key < len(obj):
            obj = obj[key]
        else:
            return default
        if obj is None:
            return default
    return obj


def _runs(text_obj) -> list:
    return (text_obj or {}).get("runs") or []


def _text(text_obj) -> str:
    if not text_obj:
        return ""
    if "simpleText" in text_obj:
        return text_obj["simpleText"]
    return "".join(r.get("text", "") for r in _runs(text_obj))


def _browse(run_or_endpoint) -> tuple[str, str]:
    """(kind, id) for a run/endpoint that opens an album, artist or playlist page."""
    ep = run_or_endpoint.get("navigationEndpoint", run_or_endpoint) if run_or_endpoint else {}
    b = (ep or {}).get("browseEndpoint") or {}
    page = _get(b, "browseEndpointContextSupportedConfigs", "browseEndpointContextMusicConfig", "pageType", default="")
    kind = PAGE_KINDS.get(page, "")
    bid = b.get("browseId", "")
    if kind == "playlist" and bid.startswith("VL"):
        bid = bid[2:]
    return (kind, bid) if kind and bid else ("", "")


def duration_ms(text: str) -> int:
    m = DURATION_RE.match((text or "").strip())
    if not m:
        return 0
    a, b, c = m.groups()
    secs = int(a) * 3600 + int(b) * 60 + int(c) if c else int(a) * 60 + int(b)
    return secs * 1000


def _resize(url: str, size: int) -> str:
    if "googleusercontent.com" in url or "ggpht.com" in url:
        url = re.sub(r"=w\d+-h\d+", f"=w{size}-h{size}", url)
        url = re.sub(r"=s\d+", f"=s{size}", url)
    return url


def _images(thumbnails) -> tuple[str, str, str]:
    thumbs = [t for t in thumbnails or [] if t.get("url")]
    if not thumbs:
        return "", "", ""
    best = max(thumbs, key=lambda t: t.get("width") or 0)["url"]
    if best.startswith("//"):
        best = "https:" + best
    if "i.ytimg.com" in best:  # video stills cannot be resized by URL
        return best, best, best
    return _resize(best, 120), _resize(best, 544), _resize(best, 1200)


def _thumbs_of(renderer) -> list:
    return (_get(renderer, "thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails")
            or _get(renderer, "thumbnailRenderer", "musicThumbnailRenderer", "thumbnail", "thumbnails")
            or _get(renderer, "thumbnail", "thumbnails")
            or [])


def _explicit(renderer) -> bool:
    for badge in renderer.get("badges") or renderer.get("subtitleBadges") or []:
        if _get(badge, "musicInlineBadgeRenderer", "icon", "iconType") == "MUSIC_EXPLICIT_BADGE":
            return True
    return False


# ---- normalised objects -------------------------------------------------------

def make_track(video_id, name, artists, artist_id="", album="", album_id="",
               images=("", "", ""), duration=0, explicit=False) -> dict:
    small, medium, large = images
    return {
        "uri": f"yt:track:{video_id}",
        "id": video_id,
        "name": name,
        "artists": ", ".join(a for a in artists if a) if isinstance(artists, (list, tuple)) else (artists or ""),
        "artistId": artist_id,
        "album": album,
        "albumId": album_id,
        "imageSmall": small,
        "image": medium,
        "imageLarge": large,
        "durationMs": duration,
        "explicit": explicit,
        "playable": True,
    }


def make_card(kind, cid, name, subtitle="", images=("", "", "")) -> dict:
    small, medium, large = images
    return {
        "kind": kind,
        "id": cid,
        "uri": f"senada:{kind}:{cid}",
        "name": name,
        "subtitle": subtitle,
        "imageSmall": small,
        "image": medium,
        "imageLarge": large,
    }


def _meta_from_runs(runs: list) -> dict:
    """Artists, album and duration out of the 'Artist • Album • 3:45' style columns."""
    artists, artist_id, album, album_id, dur, plain = [], "", "", "", 0, []
    for run in runs:
        text = (run.get("text") or "").strip()
        if not text or text in ("•", ",", "&", "dan", "and"):
            continue
        kind, bid = _browse(run)
        if kind == "artist":
            artists.append(text)
            artist_id = artist_id or bid
        elif kind == "album":
            album, album_id = text, bid
        elif "browseEndpoint" in (run.get("navigationEndpoint") or {}):
            artists.append(text)  # user channel (uploader) of a plain video
        elif duration_ms(text):
            dur = duration_ms(text)
        else:
            plain.append(text)
    if not artists:
        # unlinked artist names: the first plain value that is not a type label or a count
        for text in plain:
            low = text.lower()
            if low in TYPE_LABELS or re.search(r"\d", text) and re.search(r"(x|jt|rb|rb\.|views|plays|pemutaran|ditonton)", low):
                continue
            artists.append(text)
            break
    return {"artists": artists, "artistId": artist_id, "album": album, "albumId": album_id, "durationMs": dur}


def _list_item(r: dict, context: dict | None = None) -> tuple[str, dict] | None:
    """musicResponsiveListItemRenderer -> ("track", track) or ("card", card)."""
    context = context or {}
    cols = [_get(c, "musicResponsiveListItemFlexColumnRenderer", "text") or {} for c in r.get("flexColumns") or []]
    fixed = [_get(c, "musicResponsiveListItemFixedColumnRenderer", "text") or {} for c in r.get("fixedColumns") or []]
    title = _text(cols[0]) if cols else ""
    if not title:
        return None
    images = _images(_thumbs_of(r))

    video_id = _get(r, "playlistItemData", "videoId")
    if not video_id:
        for run in _runs(cols[0]):
            video_id = _get(run, "navigationEndpoint", "watchEndpoint", "videoId")
            if video_id:
                break
    if not video_id and not r.get("navigationEndpoint"):
        video_id = _get(r, "overlay", "musicItemThumbnailOverlayRenderer", "content", "musicPlayButtonRenderer",
                        "playNavigationEndpoint", "watchEndpoint", "videoId")

    if video_id:
        runs = [run for col in cols[1:] for run in _runs(col)] + [run for col in fixed for run in _runs(col)]
        meta = _meta_from_runs(runs)
        artists = meta["artists"] or context.get("artists") or []
        return "track", make_track(
            video_id, title, artists,
            artist_id=meta["artistId"] or context.get("artistId", ""),
            album=meta["album"] or context.get("album", ""),
            album_id=meta["albumId"] or context.get("albumId", ""),
            images=images if images[0] else context.get("images", ("", "", "")),
            duration=meta["durationMs"],
            explicit=_explicit(r),
        )

    kind, bid = _browse(r)
    if not kind:
        return None
    subtitle = SEPARATOR.join(t for t in (_text(c) for c in cols[1:2]) if t)
    return "card", make_card(kind, bid, title, subtitle, images)


def _two_row(r: dict) -> tuple[str, dict] | None:
    """musicTwoRowItemRenderer (carousel tile) -> ("track", track) or ("card", card)."""
    title = _text(r.get("title"))
    if not title:
        return None
    images = _images(_thumbs_of(r))
    nav = r.get("navigationEndpoint") or {}
    video_id = _get(nav, "watchEndpoint", "videoId")
    if video_id:
        meta = _meta_from_runs(_runs(r.get("subtitle")))
        return "track", make_track(video_id, title, meta["artists"], meta["artistId"],
                                   meta["album"], meta["albumId"], images, meta["durationMs"], _explicit(r))
    kind, bid = _browse(nav)
    if not kind:
        return None
    return "card", make_card(kind, bid, title, _text(r.get("subtitle")), images)


def parse_item(item: dict, context: dict | None = None):
    if "musicResponsiveListItemRenderer" in item:
        return _list_item(item["musicResponsiveListItemRenderer"], context)
    if "musicTwoRowItemRenderer" in item:
        return _two_row(item["musicTwoRowItemRenderer"])
    if "playlistPanelVideoRenderer" in item:
        return _panel_item(item["playlistPanelVideoRenderer"])
    return None


def _split(items, context=None) -> tuple[list, list]:
    tracks, cards = [], []
    for it in items or []:
        parsed = parse_item(it, context)
        if parsed:
            (tracks if parsed[0] == "track" else cards).append(parsed[1])
    return tracks, cards


def _shelf_title(shelf: dict) -> str:
    return _text(shelf.get("title")) or _text(_get(shelf, "header", "musicCarouselShelfBasicHeaderRenderer", "title"))


def _sections(contents) -> list[dict]:
    out = []
    for s in contents or []:
        shelf = s.get("musicCarouselShelfRenderer") or s.get("musicShelfRenderer")
        if not shelf:
            continue
        tracks, cards = _split(shelf.get("contents"))
        if tracks or cards:
            out.append({"title": _shelf_title(shelf), "tracks": tracks, "cards": cards})
    return out


def _section_list(resp: dict) -> dict:
    tab = _get(resp, "contents", "singleColumnBrowseResultsRenderer", "tabs", 0, "tabRenderer", "content") \
        or _get(resp, "contents", "twoColumnBrowseResultsRenderer", "tabs", 0, "tabRenderer", "content") or {}
    return tab.get("sectionListRenderer") or {}


# ---- public API ---------------------------------------------------------------

def _browse_sections(browse_id: str, pages: int = 1) -> list[dict]:
    resp = _post("browse", {"browseId": browse_id})
    sl = _section_list(resp)
    sections = _sections(sl.get("contents"))
    token = _get(sl, "continuations", 0, "nextContinuationData", "continuation")
    for _ in range(pages - 1):
        if not token:
            break
        try:
            more = _post("browse", {"continuation": token})
        except YTMusicError:
            break
        cont = _get(more, "continuationContents", "sectionListContinuation") or {}
        sections += _sections(cont.get("contents"))
        token = _get(cont, "continuations", 0, "nextContinuationData", "continuation")
    return sections


def home() -> list[dict]:
    """Shelves for the start page: personalised-free home, new releases and charts."""
    jobs = {"home": lambda: _browse_sections("FEmusic_home", pages=3),
            "explore": lambda: _browse_sections("FEmusic_explore"),
            "charts": lambda: _browse_sections("FEmusic_charts")}
    results = {}
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = {k: pool.submit(fn) for k, fn in jobs.items()}
        for k, f in futures.items():
            try:
                results[k] = f.result()
            except YTMusicError:
                results[k] = []
    if not any(results.values()):
        raise YTMusicError("Beranda YouTube Music tidak bisa dimuat. Periksa koneksi internet.")
    seen, out = set(), []
    for key in ("home", "explore", "charts"):
        for s in results[key]:
            if s["title"] in seen:
                continue
            seen.add(s["title"])
            out.append(s)
    return out


def _search_shelf(query: str, params: str) -> tuple[list, list]:
    resp = _post("search", {"query": query, "params": params})
    contents = _get(resp, "contents", "tabbedSearchResultsRenderer", "tabs", 0, "tabRenderer", "content",
                    "sectionListRenderer", "contents") or []
    tracks, cards = [], []
    for s in contents:
        shelf = s.get("musicShelfRenderer")
        if shelf:
            t, c = _split(shelf.get("contents"))
            tracks += t
            cards += c
    return tracks, cards


def search(query: str) -> dict:
    query = (query or "").strip()
    if not query:
        return {"tracks": [], "artists": [], "albums": [], "playlists": []}
    filters = {"tracks": FILTER_SONGS, "albums": FILTER_ALBUMS, "artists": FILTER_ARTISTS, "playlists": FILTER_PLAYLISTS}
    out, errors = {}, []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {k: pool.submit(_search_shelf, query, p) for k, p in filters.items()}
        for k, f in futures.items():
            try:
                tracks, cards = f.result()
            except YTMusicError as e:
                errors.append(e)
                tracks, cards = [], []
            if k == "tracks":
                out[k] = tracks[:20]
            else:
                want = k[:-1]  # albums -> album
                out[k] = [c for c in cards if c["kind"] == want][:12]
    if len(errors) == len(filters):
        raise errors[0]
    return out


def _responsive_header(resp: dict) -> dict:
    sl = _section_list(resp)
    for s in sl.get("contents") or []:
        for key in ("musicResponsiveHeaderRenderer", "musicEditablePlaylistDetailHeaderRenderer"):
            if key in s:
                h = s[key]
                if key == "musicEditablePlaylistDetailHeaderRenderer":
                    h = _get(h, "header", "musicResponsiveHeaderRenderer") or h
                return h
    return _get(resp, "header", "musicDetailHeaderRenderer") or {}


def _secondary(resp: dict) -> list:
    return _get(resp, "contents", "twoColumnBrowseResultsRenderer", "secondaryContents",
                "sectionListRenderer", "contents") or []


def album(browse_id: str) -> dict:
    resp = _post("browse", {"browseId": browse_id})
    h = _responsive_header(resp)
    name = _text(h.get("title"))
    artist_runs = _runs(h.get("straplineTextOne")) or _runs(h.get("subtitle"))
    meta = _meta_from_runs(artist_runs)
    images = _images(_thumbs_of(h))
    sub = [r.get("text", "") for r in _runs(h.get("subtitle")) if r.get("text", "").strip() not in ("•", "")]
    type_label = sub[0] if sub else "Album"
    year = next((s for s in sub if re.fullmatch(r"\d{4}", s)), "")
    context = {"artists": meta["artists"], "artistId": meta["artistId"], "album": name,
               "albumId": browse_id, "images": images}
    tracks, more = [], []
    for s in _secondary(resp):
        shelf = s.get("musicShelfRenderer")
        if shelf and not tracks:
            tracks, _ = _split(shelf.get("contents"), context)
        carousel = s.get("musicCarouselShelfRenderer")
        if carousel:
            _, cards = _split(carousel.get("contents"))
            if cards:
                more.append({"title": _shelf_title(carousel), "cards": cards, "tracks": []})
    for t in tracks:  # album rows only carry the title; fill the rest from the header
        t["album"], t["albumId"] = name, browse_id
        if not t["imageSmall"]:
            t["imageSmall"], t["image"], t["imageLarge"] = images
    card = make_card("album", browse_id, name, ", ".join(meta["artists"]), images)
    return {**card, "typeLabel": type_label, "year": year, "description": _text(_get(h, "description", "musicDescriptionShelfRenderer", "description")),
            "artistId": meta["artistId"], "tracks": tracks, "sections": more, "playUri": card["uri"]}


def _playlist_tracks(resp: dict, limit: int) -> list:
    tracks, token, legacy = [], None, None
    for s in _secondary(resp) or (_section_list(resp).get("contents") or []):
        shelf = s.get("musicPlaylistShelfRenderer") or s.get("musicShelfRenderer")
        if not shelf:
            continue
        items = shelf.get("contents") or []
        t, _ = _split(items)
        tracks += t
        last = items[-1] if items else {}
        token = _get(last, "continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token")
        legacy = _get(shelf, "continuations", 0, "nextContinuationData", "continuation")
        break
    while (token or legacy) and len(tracks) < limit:
        try:
            if token:
                more = _post("browse", {"continuation": token})
                items = _get(more, "onResponseReceivedActions", 0, "appendContinuationItemsAction", "continuationItems") or []
                legacy = None
            else:
                more = _post("browse", {"continuation": legacy})
                cont = _get(more, "continuationContents", "musicPlaylistShelfContinuation") or {}
                items = cont.get("contents") or []
                legacy = _get(cont, "continuations", 0, "nextContinuationData", "continuation")
        except YTMusicError:
            break
        t, _ = _split(items)
        seen = {x["id"] for x in tracks}
        fresh = [x for x in t if x["id"] not in seen]
        if not fresh:
            break
        tracks += fresh
        token = _get(items[-1], "continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token") if items else None
    return tracks[:limit]


def playlist(playlist_id: str, limit: int = 500) -> dict:
    resp = _post("browse", {"browseId": playlist_id if playlist_id.startswith("VL") else "VL" + playlist_id})
    h = _responsive_header(resp)
    name = _text(h.get("title")) or "Playlist"
    images = _images(_thumbs_of(h))
    owner = _text(h.get("straplineTextOne"))
    sub = _text(h.get("subtitle"))
    tracks = _playlist_tracks(resp, limit)
    if not images[0] and tracks:
        images = (tracks[0]["imageSmall"], tracks[0]["image"], tracks[0]["imageLarge"])
    pid = playlist_id[2:] if playlist_id.startswith("VL") else playlist_id
    card = make_card("playlist", pid, name, owner or sub, images)
    return {**card, "typeLabel": "Playlist", "description": _text(_get(h, "description", "musicDescriptionShelfRenderer", "description")),
            "tracks": tracks, "playUri": card["uri"]}


def artist(channel_id: str) -> dict:
    resp = _post("browse", {"browseId": channel_id})
    h = _get(resp, "header", "musicImmersiveHeaderRenderer") or _get(resp, "header", "musicVisualHeaderRenderer") or {}
    name = _text(h.get("title"))
    images = _images(_thumbs_of(h) or _get(h, "foregroundThumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails"))
    tracks, albums, sections, songs_playlist = [], [], [], ""
    for s in _section_list(resp).get("contents") or []:
        shelf = s.get("musicShelfRenderer")
        if shelf and not tracks:
            tracks, _ = _split(shelf.get("contents"), {"artists": [name], "artistId": channel_id})
            for run in _runs(shelf.get("title")):
                kind, bid = _browse(run)
                if kind == "playlist":
                    songs_playlist = bid
            continue
        carousel = s.get("musicCarouselShelfRenderer")
        if not carousel:
            continue
        _, cards = _split(carousel.get("contents"))
        if not cards:
            continue
        if all(c["kind"] == "album" for c in cards) and len(sections) == 0:
            albums += cards
        else:
            sections.append({"title": _shelf_title(carousel), "cards": cards, "tracks": []})
    monthly = _text(h.get("monthlyListenerCount"))
    card = make_card("artist", channel_id, name, "Artis", images)
    play_uri = f"senada:playlist:{songs_playlist}" if songs_playlist else card["uri"]
    return {**card, "typeLabel": "Artis", "genres": monthly, "tracks": tracks, "albums": albums,
            "sections": sections, "playUri": play_uri, "songsPlaylist": songs_playlist}


def _panel_item(r: dict):
    video_id = r.get("videoId")
    title = _text(r.get("title"))
    if not video_id or not title:
        return None
    meta = _meta_from_runs(_runs(r.get("longBylineText")))
    return "track", make_track(video_id, title, meta["artists"], meta["artistId"], meta["album"], meta["albumId"],
                               _images(_thumbs_of(r)), duration_ms(_text(r.get("lengthText"))), _explicit(r))


def up_next(video_id: str, radio: bool = True) -> list[dict]:
    """The track itself followed by YouTube Music's radio for it."""
    body = {"videoId": video_id, "isAudioOnly": True}
    if radio:
        body["playlistId"] = "RDAMVM" + video_id
    resp = _post("next", body)
    panel = _get(resp, "contents", "singleColumnMusicWatchNextResultsRenderer", "tabbedRenderer",
                 "watchNextTabbedResultsRenderer", "tabs", 0, "tabRenderer", "content", "musicQueueRenderer",
                 "content", "playlistPanelRenderer", "contents") or []
    tracks, _ = _split(panel)
    return tracks


def track(video_id: str) -> dict | None:
    tracks = up_next(video_id, radio=False)
    return next((t for t in tracks if t["id"] == video_id), tracks[0] if tracks else None)
