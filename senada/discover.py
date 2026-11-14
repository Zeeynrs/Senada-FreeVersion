"""Recommendations for the Search page before anything is typed: songs, artists and albums.

They grow out of what the user listens to: the artists heard most (recent plays count
double, liked songs once) and the last songs played. For each of those songs YouTube Music's
radio gives songs like it; each artist's page gives related artists ("Fans might also like")
and albums; the songs found bring their albums too. Songs that were just played are left
out. Whatever is still short (a new user has no history) is filled from the YouTube Music
home shelves: what is popular right now.
"""

from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from itertools import chain, zip_longest

from . import ytmusic
from .i18n import tr

SEED_ARTISTS = 3
SEED_SONGS = 2
LIMIT = 12


def video_id(uri: str) -> str:
    return uri.split(":", 2)[2] if (uri or "").startswith("yt:track:") else ""


def seeds(history: list[dict], liked: list[dict]) -> dict:
    """The artists heard most and the last songs played (YouTube Music ids)."""
    counts = Counter()
    for weight, tracks in ((2, history), (1, liked)):
        for t in tracks:
            aid = t.get("artistId") or ""
            if aid.startswith("UC"):  # a YouTube Music channel (imported Spotify songs have others)
                counts[aid] += weight
    songs = list(dict.fromkeys(v for v in (video_id(t.get("uri")) for t in history + liked) if v))
    return {"artists": [a for a, _ in counts.most_common(SEED_ARTISTS)], "songs": songs[:SEED_SONGS]}


def interleave(*lists):
    """One from each list in turn, so no single seed fills the shelf."""
    return [x for x in chain.from_iterable(zip_longest(*lists)) if x is not None]


def unique(items, key, skip=()):
    seen, out = set(skip), []
    for item in items:
        k = item.get(key)
        if k and k not in seen:
            seen.add(k)
            out.append(item)
    return out


def album_of(track: dict) -> dict | None:
    """An album card for the album a song is on."""
    if not (track.get("albumId") or "").startswith("MPREb_") or not track.get("album"):
        return None
    images = (track.get("imageSmall", ""), track.get("image", ""), track.get("imageLarge", ""))
    subtitle = " • ".join(x for x in (tr("Album"), track.get("artists", "")) if x)
    return ytmusic.make_card("album", track["albumId"], track["album"], subtitle, images)


def _fetch(jobs: dict) -> dict:
    """Run the lookups side by side; one that fails is just missing."""
    if not jobs:
        return {}
    out = {}
    with ThreadPoolExecutor(max_workers=min(5, len(jobs))) as pool:
        futures = {key: pool.submit(fn) for key, fn in jobs.items()}
        for key, f in futures.items():
            try:
                out[key] = f.result()
            except Exception:  # noqa: BLE001 (network, parsing: leave this one out)
                out[key] = None
    return out


def from_home(sections: list[dict]) -> dict:
    tracks = [t for s in sections for t in s.get("tracks") or []]
    cards = [c for s in sections for c in s.get("cards") or []]
    return {"tracks": tracks,
            "artists": [c for c in cards if c.get("kind") == "artist"],
            "albums": [c for c in cards if c.get("kind") == "album"]}


def build(picked: dict, home_sections: list[dict], played: set[str]) -> dict:
    """Songs, artists and albums for these seeds; `played` are song uris to leave out."""
    jobs = {("radio", v): (lambda v=v: ytmusic.up_next(v)) for v in picked["songs"]}
    jobs.update({("artist", a): (lambda a=a: ytmusic.artist(a)) for a in picked["artists"]})
    found = _fetch(jobs)

    radios = [(found.get(("radio", v)) or [])[1:] for v in picked["songs"]]  # [0] is the song itself
    pages = [found.get(("artist", a)) or {} for a in picked["artists"]]
    related = [[c for s in p.get("sections") or [] for c in s.get("cards") or [] if c.get("kind") == "artist"]
               for p in pages]

    tracks = unique(interleave(*radios), "uri", skip=played)
    artists = unique(interleave(*related), "id", skip=picked["artists"])
    albums = unique(interleave(*[(p.get("albums") or [])[:4] for p in pages],
                               [a for a in map(album_of, tracks) if a]), "id")
    personal = bool(tracks or artists or albums)

    if len(tracks) < 6 or len(artists) < 4 or len(albums) < 4:
        if not home_sections:
            home_sections = (_fetch({"home": ytmusic.home}).get("home") or [])
        home = from_home(home_sections)
        tracks = unique(tracks + home["tracks"], "uri", skip=played if personal else ())
        artists = unique(artists + home["artists"], "id", skip=picked["artists"])
        albums = unique(albums + home["albums"], "id")
    if not (tracks or artists or albums):
        raise ytmusic.YTMusicError(tr("Recommendations could not be loaded. Check the internet connection."))
    return {"tracks": tracks[:LIMIT], "artists": artists[:LIMIT], "albums": albums[:LIMIT], "personal": personal}
