"""Match a track known only by metadata (e.g. imported from Spotify) to a YouTube Music upload.

Every candidate gets a 0-100 score built from:
  title similarity     up to 45   (after stripping "official video", "lirik", "feat. …", …)
  artist similarity    up to 30
  duration agreement   up to 20   (far-off durations disqualify)
  upload type          up to  5   (official song > music video > user upload)
minus penalties when the candidate is a different *version* of the song
(live, remix, cover, karaoke, instrumental, slowed, sped up, …) than the one asked for.
"""

import re
import unicodedata
from difflib import SequenceMatcher

MATCHER_VERSION = 2  # bump when scoring changes so cached matches are redone
ACCEPT = 70          # confident: stop searching
MINIMUM = 45         # below this the candidate is treated as "not found"

# version tags: a candidate carrying one the source lacks (or the reverse) is another recording
VERSION_TAGS = {
    "live": r"\blive\b|\blive at\b|\bkonser\b|\bconcert\b|\bunplugged\b|\blangsung\b",
    "remix": r"\bremix(?:ed)?\b|\brmx\b|\bbootleg\b|\bmash ?up\b|\bflip\b|\bvip mix\b",
    "acoustic": r"\bacoustic\b|\bakustik\b|\bunplugged\b",
    "cover": r"\bcover(?:ed)?\b|\bcovered by\b|\btribute\b",
    "karaoke": r"\bkaraoke\b|\bminus one\b|\bbacking track\b|\bsing ?along\b",
    "instrumental": r"\binstrumental\b|\binstrumen\b|\bpiano version\b|\bpiano cover\b|\bguitar cover\b",
    "slowed": r"\bslowed\b|\breverb\b",
    "sped": r"\bsped ?up\b|\bspeed ?up\b|\bnightcore\b",
    "8d": r"\b8d\b|\b16d\b",
    "extended": r"\bextended\b|\bloop\b|\b1 hour\b|\b1 jam\b",
    "demo": r"\bdemo\b",
}
TAG_RES = {tag: re.compile(rx, re.I) for tag, rx in VERSION_TAGS.items()}

# decorations that say nothing about which recording it is
NOISE_RE = re.compile(
    r"\b(?:official|resmi)\s*(?:music\s*)?(?:video|audio|mv|lyric(?:s)?\s*video|visuali[sz]er|clip)\b"
    r"|\b(?:music|lyric(?:s)?|video)\s*(?:video|klip|clip)\b"
    r"|\bvideo\s*(?:musik|lirik|klip)\b"
    r"|\b(?:with\s*)?lyrics?\b|\blirik(?:\s*lagu)?\b"
    r"|\b(?:hd|hq|4k|1080p|720p|mv|m/v|audio|visuali[sz]er|explicit|clean|full\s*album)\b"
    r"|\b(?:\d{4}\s*)?remaster(?:ed)?(?:\s*\d{4})?(?:\s*version)?\b"
    r"|\bradio\s*edit\b|\balbum\s*version\b|\bsingle\s*version\b|\boriginal\s*mix\b",
    re.I,
)
# a bare "with" is deliberately not a credit ("Dance With Me"); only "(with X)" in brackets is
FEAT_RE = re.compile(r"[\(\[]\s*with\s+([^\)\]]+)[\)\]]"
                     r"|[\(\[]?\s*\b(?:feat\.?|ft\.?|featuring)\s+([^\)\]\-–|]+)[\)\]]?", re.I)
LYRIC_RE = re.compile(r"\blyrics?\b|\blirik\b", re.I)
ARTIST_SPLIT_RE = re.compile(r"\s*(?:,|&|\bx\b|\band\b|\bdan\b|\bfeat\.?|\bft\.?|\bfeaturing\b|\bwith\b|/|;)\s*", re.I)
DASHES = dict.fromkeys(map(ord, "‐‑‒–—―−"), "-")


def _fold(text: str) -> str:
    """Lowercase, strip accents and unify dashes/quotes."""
    text = unicodedata.normalize("NFKD", text or "").translate(DASHES)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return text.replace("’", "'").replace("`", "'").lower()


def _squash(text: str) -> str:
    """Letters/digits only, single spaces."""
    text = re.sub(r"[^\w\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def version_tags(text: str) -> set[str]:
    folded = _fold(text)
    return {tag for tag, rx in TAG_RES.items() if rx.search(folded)}


def split_artists(text: str) -> list[str]:
    parts = [_squash(_fold(p)) for p in ARTIST_SPLIT_RE.split(text or "")]
    return [p for p in parts if p]


def featured(text: str) -> list[str]:
    """Artists named in a 'feat. X' part of a title."""
    out = []
    for m in FEAT_RE.finditer(_fold(text)):
        out += split_artists(m.group(1) or m.group(2) or "")
    return out


def clean_title(text: str) -> str:
    """Comparable title: no feat., no decorations, no punctuation. Version words stay
    (they are compared separately and must still be visible to version_tags)."""
    t = _fold(text)
    t = FEAT_RE.sub(" ", t)
    t = NOISE_RE.sub(" ", t)
    t = re.sub(r"[\(\)\[\]\{\}|\"]", " ", t)
    return _squash(t)


def _ratio(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


def _tokens(text: str) -> set[str]:
    return set(text.split())


def title_similarity(source: str, candidate: str, candidate_artists: list[str]) -> float:
    """0..1. Tolerates 'Artist - Title' style candidate titles and extra decoration words."""
    src = clean_title(source)
    cand = clean_title(candidate)
    if not src or not cand:
        return 0.0
    # drop the artist name that uploaders put in front of / behind the title
    stripped = cand
    for name in candidate_artists:
        if name and name in stripped and name != src:
            stripped = _squash(stripped.replace(name, " "))
    stripped = _squash(stripped.replace(" - ", " ").strip("- "))
    if src in (cand, stripped):
        return 1.0
    best = max(_ratio(src, cand), _ratio(src, stripped))
    st, ct = _tokens(src), _tokens(stripped or cand)
    if st:
        covered = len(st & ct) / len(st)                 # all source words present?
        extra = len(ct - st) / max(1, len(ct))           # how much else is in the candidate
        best = max(best, covered * (1 - 0.5 * extra))
    # near-misses ("Evakuasi" vs "Evaluasi") are different songs more often than typos: widen the gap
    return min(1.0, best) ** 2


def artist_similarity(source_artists: list[str], candidate_artists: list[str], candidate_title: str) -> float:
    """0..1: how well the candidate's credited artists (or its title) name the source artists."""
    if not source_artists:
        return 0.5  # nothing to compare against
    title = _squash(_fold(candidate_title))
    best = 0.0
    for i, src in enumerate(source_artists):
        weight = 1.0 if i == 0 else 0.8  # the primary artist matters most
        for cand in candidate_artists:
            if not cand:
                continue
            if src == cand or (len(src) > 3 and (src in cand or cand in src)):
                best = max(best, weight)
            else:
                # names either match or they don't: only near-identical spellings count
                r = _ratio(src, cand)
                if r >= 0.85:
                    best = max(best, weight * r)
        if len(src) > 2 and re.search(r"\b" + re.escape(src) + r"\b", title):
            best = max(best, weight * 0.9)  # uploader put the artist in the title
    return best


def duration_points(source_ms: int, candidate_ms: int) -> tuple[float, bool]:
    """(points out of 20, disqualified)."""
    if not source_ms or not candidate_ms:
        return 8.0, False  # unknown: neutral
    delta = abs(source_ms - candidate_ms) / 1000
    if delta <= 2:
        return 20.0, False
    if delta <= 15:
        return 20.0 * (1 - (delta - 2) / 13), False
    return 0.0, delta > 30


TYPE_POINTS = {"MUSIC_VIDEO_TYPE_ATV": 5, "MUSIC_VIDEO_TYPE_OMV": 2, "MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC": 2}


def score(source: dict, candidate: dict) -> dict:
    """Score one candidate against the source track. Both are track dicts
    (name, artists, durationMs); candidates may also carry videoType."""
    src_title = source.get("name") or ""
    src_artists = split_artists(source.get("artists") or "") + featured(src_title)
    cand_title = candidate.get("name") or ""
    cand_artists = split_artists(candidate.get("artists") or "") + featured(cand_title)

    t = title_similarity(src_title, cand_title, cand_artists)
    a = artist_similarity(src_artists, cand_artists, cand_title)
    d, disqualified = duration_points(source.get("durationMs") or 0, candidate.get("durationMs") or 0)
    kind = TYPE_POINTS.get(candidate.get("videoType") or "", 0)

    src_tags = version_tags(src_title)
    cand_tags = version_tags(cand_title + " " + (candidate.get("album") or ""))
    penalty = 0
    for tag in cand_tags - src_tags:
        penalty += 40 if tag in ("karaoke", "cover", "instrumental") else 30
    for tag in src_tags - cand_tags:
        penalty += 18  # asked for e.g. a live/remix version, got something else
    if a < 0.4:
        penalty += 15  # almost certainly someone else's song
    if candidate.get("videoType") == "MUSIC_VIDEO_TYPE_UGC" and LYRIC_RE.search(cand_title):
        penalty += 6   # fan lyric uploads: often re-encoded, trimmed or sped up

    total = 45 * t + 30 * a + d + kind - penalty
    if disqualified:
        total = min(total, MINIMUM - 1)
    return {
        "score": max(0, min(100, round(total))),
        "title": round(t, 3), "artist": round(a, 3), "duration": round(d, 1),
        "tags": sorted(cand_tags), "disqualified": disqualified,
    }


def rank(source: dict, candidates: list[dict]) -> list[dict]:
    """Candidates with a `match` field, best first (duplicates by video id dropped)."""
    seen, out = set(), []
    for c in candidates:
        vid = c.get("id")
        if not vid or vid in seen:
            continue
        seen.add(vid)
        out.append({**c, "match": score(source, c)})
    out.sort(key=lambda c: c["match"]["score"], reverse=True)
    return out


def search_query(source: dict) -> str:
    """'Primary Artist Title' without decorations that only confuse the search."""
    artists = split_artists(source.get("artists") or "")
    title = _fold(source.get("name") or "")
    title = FEAT_RE.sub(" ", title)
    title = re.sub(r"\s*-\s*(?:\d{4}\s*)?remaster(?:ed)?.*$", "", title)
    title = re.sub(r"[\(\[][^\)\]]*remaster[^\)\]]*[\)\]]", " ", title)
    return re.sub(r"\s+", " ", f"{artists[0] if artists else ''} {title}").strip()
