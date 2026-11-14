"""Lyrics from several free sources, chosen in Settings or from the lyrics panel.

  betterlyrics  BetterLyrics (https://betterlyrics.org), timed word by word, often
                with a romanization and an English translation of each line
  lrclib        LRCLIB (https://lrclib.net), a free public lyrics database
  kugou         KuGou Music, strong on Chinese, Japanese and Korean songs, word by word
  ytmusic       YouTube Music's own lyrics for the playing video (timed where it has them)
  netease       NetEase Cloud Music, large catalogue of synced LRC files
  auto          the sources above in that order: the first synced lyrics win, otherwise
                the first plain ones

Each line is {"t": start in ms, "text"}; word-timed sources add "words": [{"t", "d", "text"}]
(start and length in ms, the text with the space after it, so the words join up to the line),
and a line can carry "roman" (its romanization) and "trans" (an English translation).
"""

import base64
import bisect
import json
import re
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zlib

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import i18n, matching, net, ytmusic

LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
HEADERS = {"User-Agent": "Senada/0.1 (desktop music player)"}

SOURCES = ("auto", "betterlyrics", "lrclib", "kugou", "ytmusic", "netease")
# word-timed lyrics first, so karaoke can follow the singer where they exist
AUTO_ORDER = ("betterlyrics", "lrclib", "kugou", "ytmusic", "netease")
SOURCE_NAMES = {"betterlyrics": "BetterLyrics", "lrclib": "LRCLIB", "kugou": "KuGou", "ytmusic": "YouTube Music",
                "netease": "NetEase"}


def parse_lrc(text: str):
    lines = []
    for raw in text.splitlines():
        stamps = LRC_LINE.findall(raw)
        words = LRC_LINE.sub("", raw).strip()
        for m, s in stamps:
            lines.append({"t": int((int(m) * 60 + float(s)) * 1000), "text": words})
    lines.sort(key=lambda l: l["t"])
    return lines


def _plain(text: str):
    return {"synced": False, "lines": [{"t": 0, "text": l} for l in text.strip().splitlines()]}


def _instrumental():
    return {"synced": False, "lines": [{"t": 0, "text": "♪ Instrumental ♪"}]}


def _get_json(url, headers=HEADERS, data=None, timeout=10):
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with net.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


# ---- LRCLIB ----------------------------------------------------------------------

def _lrclib(path, **params):
    return _get_json("https://lrclib.net/api" + path + "?" + urllib.parse.urlencode(params))


def fetch_lrclib(track: dict):
    params = {"track_name": track["name"], "artist_name": track["artists"].split(",")[0]}
    hit = _lrclib("/get", **params, album_name=track.get("album", ""),
                  duration=round(track.get("durationMs", 0) / 1000))
    if not hit or not (hit.get("syncedLyrics") or hit.get("plainLyrics")):
        results = _lrclib("/search", **params) or []
        hit = next((r for r in results if r.get("syncedLyrics")), None) or \
            next((r for r in results if r.get("plainLyrics")), None) or \
            next((r for r in results if r.get("instrumental")), None)
    if not hit:
        return None
    if hit.get("syncedLyrics"):
        return {"synced": True, "lines": parse_lrc(hit["syncedLyrics"])}
    if hit.get("instrumental"):
        return _instrumental()
    return _plain(hit["plainLyrics"])


# ---- BetterLyrics (TTML) ----------------------------------------------------------

TT = "{http://www.w3.org/ns/ttml}"
ITUNES = "{http://music.apple.com/lyric-ttml-internal}"
TTML_TIME = re.compile(r"^(?:(\d+):)?(?:(\d+):)?(\d+(?:\.\d+)?)s?$")


def ttml_ms(value):
    """TTML clock values: "27.395", "1:02.345", "0:01:02.345" (or "12.5s") -> ms (None if unreadable)."""
    m = TTML_TIME.match((value or "").strip())
    if not m:
        return None
    a, b, sec = m.groups()
    hours, minutes = (int(a), int(b)) if b is not None else (0, int(a or 0))
    return round((hours * 3600 + minutes * 60 + float(sec)) * 1000)


def _ttml_words(el) -> list[dict]:
    """The timed words inside a <p> (or a transliteration's <text>): each span is a word or a
    syllable; the text between spans (a space) belongs to the word before it. Background vocals
    (a span holding spans) come in brackets where they are sung."""
    words = []
    for span in el:
        if span.tag != TT + "span":
            continue
        if any(c.tag == TT + "span" for c in span):  # background vocals: "(ooh)"
            sub = _ttml_words(span)
            if sub:
                if words and not words[-1]["text"].endswith(" "):
                    words[-1]["text"] += " "
                sub[0]["text"] = "(" + sub[0]["text"].lstrip()
                sub[-1]["text"] = sub[-1]["text"].rstrip() + ")"
                words += sub
        else:
            start, end = ttml_ms(span.get("begin")), ttml_ms(span.get("end"))
            if start is not None and span.text:
                words.append({"t": start, "d": max(0, (end if end is not None else start) - start),
                              "text": span.text})
        if span.tail and words:
            words[-1]["text"] += " " if not span.tail.strip() else span.tail
    if words:
        words[-1]["text"] = words[-1]["text"].rstrip()
    return words


def parse_ttml(ttml: str):
    """{"synced", "lines"} from Apple-style TTML (timed by word, by line, or not at all), with the
    romanization and the translation of each line where the file has them."""
    root = ET.fromstring(ttml)
    timing = (root.get(ITUNES + "timing") or "").lower()
    extra = {}  # itunes:key of a line -> {"roman": ..., "trans": ...}
    for tl in root.iter(ITUNES + "transliteration"):
        for text in tl.iter(ITUNES + "text"):
            words = _ttml_words(text)
            line = "".join(w["text"] for w in words) if words else "".join(text.itertext())
            extra.setdefault(text.get("for"), {})["roman"] = " ".join(line.split())
        break  # one script is enough
    for tr in root.iter(ITUNES + "translation"):
        for text in tr.iter(ITUNES + "text"):
            extra.setdefault(text.get("for"), {})["trans"] = " ".join("".join(text.itertext()).split())
        break
    lines = []
    for p in root.iter(TT + "p"):
        start = ttml_ms(p.get("begin"))
        words = _ttml_words(p) if timing == "word" else []
        text = "".join(w["text"] for w in words) if words else " ".join("".join(p.itertext()).split())
        line = {"t": start if start is not None else 0, "text": text.strip()}
        if words:
            line["words"] = words
        line.update({k: v for k, v in extra.get(p.get(ITUNES + "key"), {}).items() if v})
        lines.append(line)
    synced = timing in ("word", "line") and any(l["t"] for l in lines)
    if synced:
        lines.sort(key=lambda l: l["t"])
    return {"synced": synced, "lines": lines}


def fetch_betterlyrics(track: dict):
    params = {"s": track["name"], "a": track["artists"].split(",")[0],
              "d": round(track.get("durationMs", 0) / 1000)}
    if track.get("album"):
        params["al"] = track["album"]
    found = _get_json("https://lyrics-api.boidu.dev/getLyrics?" + urllib.parse.urlencode(params)) or {}
    ttml = found.get("ttml") or ""
    if not ttml.strip():
        return None
    try:
        data = parse_ttml(ttml)
    except ET.ParseError as e:
        raise ValueError(f"BetterLyrics sent unreadable TTML: {e}") from e
    return data if data["lines"] else None


# ---- KuGou (KRC) ------------------------------------------------------------------

KRC_KEY = bytes((64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105))
KRC_LINE = re.compile(r"^\[(\d+),(\d+)\](.*)$")
KRC_WORD = re.compile(r"<(\d+),(\d+),\d+>([^<]*)")
# credits at the top of KuGou lyrics: "Lyrics by：…", "作词：…"
KUGOU_CREDIT = re.compile(r"[：]|^\s*(?:lyrics|music|composed|produced|arranged|written)\s+by\b", re.I)


def decode_krc(content: str) -> str:
    """KuGou's KRC files: base64 of "krc1" and zlib data XOR-ed with a fixed key."""
    raw = base64.b64decode(content)
    if raw[:4] != b"krc1":
        raise ValueError("not a KRC file")
    return zlib.decompress(bytes(b ^ KRC_KEY[i % 16] for i, b in enumerate(raw[4:]))).decode("utf-8", "replace")


def parse_krc(text: str, track: dict | None = None):
    """{"synced", "lines"} from a decoded KRC: "[start,length]<offset,length,0>word…" per line,
    each word's offset counted from the start of its line."""
    lines = []
    title = matching.normalize((track or {}).get("name", ""))
    for raw in text.splitlines():
        m = KRC_LINE.match(raw.strip())
        if not m:
            continue
        start = int(m.group(1))
        words = [{"t": start + int(o), "d": int(d), "text": w} for o, d, w in KRC_WORD.findall(m.group(3)) if w]
        line_text = "".join(w["text"] for w in words).strip()
        if not line_text or KUGOU_CREDIT.search(line_text):
            continue
        if not lines and title and " - " in line_text and title in matching.normalize(line_text):
            continue  # "Title - Artist" before the song starts
        words[-1]["text"] = words[-1]["text"].rstrip()
        lines.append({"t": start, "text": line_text, "words": words})
    lines.sort(key=lambda l: l["t"])
    return {"synced": bool(lines), "lines": lines}


def fetch_kugou(track: dict):
    # KuGou's song search answers over plain http only; it gets the song and the artist, nothing else
    found = _get_json("http://mobilecdn.kugou.com/api/v3/search/song?" + urllib.parse.urlencode(
        {"format": "json", "keyword": matching.search_query(track), "page": 1, "pagesize": 10})) or {}
    songs = (found.get("data") or {}).get("info") or []
    candidates = [{"id": s["hash"], "name": s.get("songname", ""), "artists": s.get("singername", ""),
                   "durationMs": int(s.get("duration") or 0) * 1000} for s in songs if s.get("hash")]
    ranked = [c for c in matching.rank(track, candidates) if c["match"]["score"] >= matching.MINIMUM]
    for song in ranked[:2]:
        found = _get_json("https://krcs.kugou.com/search?" + urllib.parse.urlencode(
            {"ver": 1, "man": "yes", "client": "mobi", "keyword": f"{song['artists']} - {song['name']}",
             "duration": song["durationMs"], "hash": song["id"]})) or {}
        for cand in (found.get("candidates") or [])[:2]:
            data = _get_json("https://lyrics.kugou.com/download?" + urllib.parse.urlencode(
                {"ver": 1, "client": "pc", "id": cand.get("id"), "accesskey": cand.get("accesskey"),
                 "fmt": "krc", "charset": "utf8"})) or {}
            try:
                parsed = parse_krc(decode_krc(data.get("content") or ""), track)
            except (ValueError, zlib.error):
                continue
            if parsed["lines"]:
                return parsed
    return None


# ---- YouTube Music ---------------------------------------------------------------

# Timed lyrics are only served to the Android app; the web client gets plain text.
ANDROID_VERSION = "7.21.50"


def _ytm_lyrics_id(video_id: str) -> str:
    resp = ytmusic._post("next", {"videoId": video_id, "isAudioOnly": True})
    tabs = ytmusic._get(resp, "contents", "singleColumnMusicWatchNextResultsRenderer", "tabbedRenderer",
                        "watchNextTabbedResultsRenderer", "tabs") or []
    for tab in tabs:
        browse_id = ytmusic._get(tab, "tabRenderer", "endpoint", "browseEndpoint", "browseId") or ""
        if browse_id.startswith("MPLY"):
            return browse_id
    return ""


def _ytm_timed(browse_id: str):
    hl, gl = ytmusic.region()
    body = {"context": {"client": {"clientName": "ANDROID_MUSIC", "clientVersion": ANDROID_VERSION,
                                   "androidSdkVersion": 30, "hl": hl, "gl": gl}},
            "browseId": browse_id}
    headers = {"Content-Type": "application/json",
               "User-Agent": f"com.google.android.apps.youtube.music/{ANDROID_VERSION} (Linux; U; Android 11) gzip"}
    resp = _get_json("https://music.youtube.com/youtubei/v1/browse?prettyPrint=false",
                     headers=headers, data=json.dumps(body).encode(), timeout=12) or {}
    data = ytmusic._get(resp, "contents", "elementRenderer", "newElement", "type", "componentType", "model",
                        "timedLyricsModel", "lyricsData", "timedLyricsData") or []
    lines = []
    for item in data:
        start = ytmusic._get(item, "cueRange", "startTimeMilliseconds")
        if start is not None:
            lines.append({"t": int(start), "text": (item.get("lyricLine") or "").strip()})
    return lines


def _ytm_plain(browse_id: str) -> str:
    resp = ytmusic._post("browse", {"browseId": browse_id})
    shelf = ytmusic._get(resp, "contents", "sectionListRenderer", "contents", 0, "musicDescriptionShelfRenderer")
    return ytmusic._text((shelf or {}).get("description"))


def fetch_ytmusic(track: dict):
    video_id = track.get("videoId")
    if not video_id:
        return None
    browse_id = _ytm_lyrics_id(video_id)
    if not browse_id:
        return None
    try:
        lines = _ytm_timed(browse_id)
    except (OSError, ValueError):
        lines = []
    if lines:
        return {"synced": True, "lines": sorted(lines, key=lambda l: l["t"])}
    text = _ytm_plain(browse_id)
    return _plain(text) if text.strip() else None


# ---- NetEase Cloud Music ---------------------------------------------------------

NETEASE_HEADERS = {"User-Agent": "Mozilla/5.0", "Referer": "https://music.163.com/"}
# "作词 : …", "作曲 : …", "编曲 : …" credit lines at the top of NetEase LRC files
CREDIT_RE = re.compile(r"^[　-鿿\s]{1,12}[:：]")
PURE_MUSIC = "纯音乐"


def fetch_netease(track: dict):
    query = matching.search_query(track)
    found = _get_json("https://music.163.com/api/search/get", NETEASE_HEADERS,
                      urllib.parse.urlencode({"s": query, "type": 1, "limit": 10}).encode()) or {}
    songs = (found.get("result") or {}).get("songs") or []
    candidates = [{"id": str(s["id"]), "name": s.get("name", ""),
                   "artists": ", ".join(a.get("name", "") for a in s.get("artists") or []),
                   "durationMs": s.get("duration", 0), "album": (s.get("album") or {}).get("name", "")}
                  for s in songs if s.get("id")]
    ranked = [c for c in matching.rank(track, candidates) if c["match"]["score"] >= matching.MINIMUM]
    for cand in ranked[:3]:
        data = _get_json(f"https://music.163.com/api/song/lyric?id={cand['id']}&lv=1&kv=1&tv=-1",
                         NETEASE_HEADERS) or {}
        text = (data.get("lrc") or {}).get("lyric") or ""
        if PURE_MUSIC in text[:200]:
            return _instrumental()
        lines = [l for l in parse_lrc(text) if not CREDIT_RE.match(l["text"])]
        if lines:
            return {"synced": True, "lines": lines}
        if text.strip() and not LRC_LINE.search(text):
            return _plain(text)
    return None


# ---- romanization and translation ----------------------------------------------------
# Shown under each line when Settings → Lyrics asks for it. A romanization comes with the
# lyrics from BetterLyrics; Korean is romanized here as well (Hangul spells its sounds, so
# no dictionary is needed). Translations: BetterLyrics' English ones, or (only when switched
# on) Google Translate into the interface language, which gets the text of the lyrics.

EXTRAS = ("off", "roman", "trans")
HANGUL = re.compile("[가-힣]")
KO_INITIAL = ("g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h")
KO_VOWEL = ("a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi",
            "yu", "eu", "ui", "i")
KO_FINAL = ("", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t",
            "ng", "t", "t", "k", "t", "p", "t")
# a final consonant before a syllable that starts with a vowel is sounded at its start (liaison)
KO_CARRY = {1: "g", 2: "kk", 4: "n", 7: "d", 8: "r", 16: "m", 17: "b", 19: "s", 20: "ss", 22: "j", 23: "ch",
            24: "k", 25: "t", 26: "p", 27: ""}
# finals that sound like k, t or p turn nasal before ㄴ or ㅁ (감사합니다: gamsahamnida)
KO_K, KO_T, KO_P = {1, 2, 3, 9, 24}, {7, 19, 20, 22, 23, 25, 27}, {14, 17, 18, 26}
KO_NASAL_NEXT = {2, 6}  # initial ㄴ, ㅁ
KO_SILENT, KO_RIEUL_INITIAL, KO_RIEUL_FINAL, KO_NIEUN_FINAL = 11, 5, 8, 4


def _syllable(ch):
    code = ord(ch) - 0xAC00
    return (code // 588, (code % 588) // 28, code % 28) if 0 <= code <= 11171 else None


def romanize_korean(text: str) -> str:
    """Revised Romanization of the Hangul in `text` (anything else is kept), with liaison and the
    common sound changes between syllables."""
    out, carried = [], None  # carried: how the next syllable starts, decided by the one before
    for i, ch in enumerate(text):
        syl = _syllable(ch)
        if syl is None:
            out.append(ch)
            carried = None
            continue
        initial, vowel, final = syl
        start = KO_INITIAL[initial] if carried is None else carried
        carried = None
        nxt = _syllable(text[i + 1]) if i + 1 < len(text) else None
        end = KO_FINAL[final]
        if nxt and final:
            n = nxt[0]
            if n == KO_SILENT and final in KO_CARRY:
                end, carried = "", KO_CARRY[final]
            elif ((final == KO_NIEUN_FINAL and n == KO_RIEUL_INITIAL)
                  or (final == KO_RIEUL_FINAL and n in (KO_RIEUL_INITIAL, 2))):
                end, carried = "l", "l"  # 신라 silla, 설날 seollal
            elif n in KO_NASAL_NEXT:
                end = "ng" if final in KO_K else "n" if final in KO_T else "m" if final in KO_P else end
        out.append(start + KO_VOWEL[vowel] + end)
    return "".join(out)


TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single"
TRANSLATE_CHUNK = 4000  # characters per request


def translate_lines(texts: list[str], target: str) -> list[str]:
    """Each text in `target` ("en", "id", …) by Google Translate; a text already in that language
    comes back empty. Lines go in a few requests, one line of text per lyric line."""
    out, chunk, size = [], [], 0
    chunks = []
    for t in texts:
        if chunk and size + len(t) + 1 > TRANSLATE_CHUNK:
            chunks.append(chunk)
            chunk, size = [], 0
        chunk.append(t.replace("\n", " "))
        size += len(t) + 1
    if chunk:
        chunks.append(chunk)
    for part in chunks:
        url = TRANSLATE_URL + "?" + urllib.parse.urlencode({"client": "gtx", "sl": "auto", "tl": target, "dt": "t"})
        data = _get_json(url, {**HEADERS, "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"},
                         urllib.parse.urlencode({"q": "\n".join(part)}).encode()) or []
        if len(data) > 2 and data[2] == target:  # the song is already in that language
            out += [""] * len(part)
            continue
        joined = "".join(seg[0] for seg in (data[0] if data else None) or [] if seg and seg[0])
        got = joined.split("\n")
        if len(got) != len(part):
            raise ValueError("the translation did not keep the lines apart")
        out += [g.strip() for g in got]
    return out


FETCHERS = {"betterlyrics": fetch_betterlyrics, "lrclib": fetch_lrclib, "kugou": fetch_kugou,
            "ytmusic": fetch_ytmusic, "netease": fetch_netease}


def fetch_lyrics(track: dict, source: str = "auto"):
    """{"synced", "lines", "source"}; lines is empty when the source has nothing."""
    if source != "auto":
        found = FETCHERS[source](track)
        return {**(found or {"synced": False, "lines": []}), "source": source}
    plain, failure = None, None
    for name in AUTO_ORDER:
        try:
            found = FETCHERS[name](track)
        except (OSError, ValueError) as e:  # one source down: try the next one
            failure = e
            continue
        if found and found["synced"]:
            return {**found, "source": name}
        if found and found["lines"] and not plain:
            plain = {**found, "source": name}
    if plain:
        return plain
    if failure:
        raise failure
    return {"synced": False, "lines": [], "source": ""}


class Lyrics(QObject):
    changed = Signal()
    currentChanged = Signal()
    sourceChanged = Signal()
    extraChanged = Signal()

    def __init__(self, player, worker, settings, downloads=None, parent=None):
        super().__init__(parent)
        self.downloads = downloads  # lyrics saved with downloaded songs, used without internet
        self.player = player
        self.worker = worker
        self.settings = settings
        self._source = settings["lyrics_source"] if settings["lyrics_source"] in SOURCES else "auto"
        self._cache = {}  # (uri, source) -> result
        self._key = ("", "")
        self._raw = []    # the lines as the source gave them
        self._lines = []  # the same, with "sub" (romanization or translation) where asked for
        self._extra = settings["lyrics_extra"] if settings["lyrics_extra"] in EXTRAS else "off"
        self._translations = {}  # (uri, source, language, lines) -> [translated line, …] ([] while it runs)
        self._times = []
        self._synced = False
        self._status = "idle"
        self._from = ""
        self._offline = False  # the lyrics shown are the ones saved with a downloaded song
        self._current = -1
        player.trackChanged.connect(self._on_track)
        player.positionChanged.connect(self._on_position)

    @Property("QVariantList", notify=changed)
    def lines(self):
        return self._lines

    @Property(bool, notify=changed)
    def synced(self):
        return self._synced

    @Property(str, notify=changed)
    def status(self):
        return self._status  # idle | loading | ready | none | error

    @Property(int, notify=currentChanged)
    def current(self):
        return self._current

    @Property("QVariantList", constant=True)
    def sources(self):
        """[{key, name}]; the "auto" name is translated in QML."""
        return [{"key": k, "name": SOURCE_NAMES.get(k, "")} for k in SOURCES]

    @Property(str, notify=sourceChanged)
    def source(self):
        return self._source

    @source.setter
    def source(self, value):
        if value in SOURCES and value != self._source:
            self._source = value
            self.settings["lyrics_source"] = value
            self.sourceChanged.emit()
            self._on_track()

    @Property(str, notify=changed)
    def sourceName(self):
        """Name of the source the shown lyrics came from (empty when nothing is shown)."""
        return SOURCE_NAMES.get(self._from, "")

    @Property(bool, notify=changed)
    def offline(self):
        """The lyrics shown were saved with the downloaded song (no internet needed)."""
        return self._offline

    # ---- under each line: romanization or translation -----------------------------------

    @Property(str, notify=extraChanged)
    def extra(self):
        """What is shown under each line: "off", "roman" or "trans"."""
        return self._extra

    @extra.setter
    def extra(self, value):
        if value in EXTRAS and value != self._extra:
            self._extra = value
            self.settings["lyrics_extra"] = value
            self.extraChanged.emit()
            self._decorate()

    @Property(bool, notify=extraChanged)
    def onlineTranslation(self):
        """Translate with Google Translate (the lyrics' text goes to Google)."""
        return bool(self.settings["lyrics_translate_online"])

    @onlineTranslation.setter
    def onlineTranslation(self, on):
        if bool(on) != self.onlineTranslation:
            self.settings["lyrics_translate_online"] = bool(on)
            self.extraChanged.emit()
            self._decorate()

    @Property(bool, notify=changed)
    def hasExtra(self):
        """Some line shows a romanization or a translation."""
        return any(l.get("sub") for l in self._lines)

    @Slot()
    def refreshExtra(self):
        """The interface language changed: translations follow it."""
        self._decorate()

    def _subs(self) -> list[str]:
        lines = self._raw
        if not lines:  # still loading: nothing to romanize or translate yet
            return []
        if self._extra == "roman":
            return [l.get("roman") or (romanize_korean(l["text"]) if HANGUL.search(l["text"]) else "")
                    for l in lines]
        if self._extra != "trans":
            return []
        given = [l.get("trans", "") for l in lines]  # BetterLyrics: English
        target = i18n.language()
        if not self.onlineTranslation or (target == "en" and any(given)):
            return given
        key = (*self._key, target, len(lines))
        if key not in self._translations:
            self._translations[key] = []
            texts = [l["text"] for l in lines]

            def done(found, key=key):
                self._translations[key] = found
                if key[:2] == self._key and len(found) == len(self._raw):
                    self._decorate()

            def failed(_e, key=key):
                self._translations.pop(key, None)  # tried again with the next song or setting change

            self.worker.run(lambda: translate_lines(texts, target), done, failed)
        return self._translations[key] or given

    def _decorate(self):
        subs = self._subs()
        self._lines = [({**l, "sub": s} if s and s.strip() != l["text"].strip() else l)
                       for l, s in zip(self._raw, subs)] if subs else list(self._raw)
        self.changed.emit()

    def _set(self, key, data, status):
        if key != self._key:
            return
        self._raw = data.get("lines", [])
        self._times = [l["t"] for l in self._raw]
        self._synced = data.get("synced", False)
        self._from = data.get("source", "") if self._raw else ""
        self._offline = bool(data.get("offline")) and bool(self._raw)
        self._status = status if self._raw or status != "ready" else "none"
        self._current = -1
        self._decorate()
        self._on_position()

    def _on_track(self):
        st = self.player.state
        uri = st.get("uri", "")
        key = (uri, self._source)
        if key == self._key and self._status == "loading":
            return  # already being looked up
        self._key = key
        if not uri:
            self._set(key, {}, "idle")
            return
        if key in self._cache:
            self._set(key, self._cache[key], "ready")
            return
        saved = self.downloads.lyrics_for(uri) if self.downloads is not None else None
        if saved:
            saved["offline"] = True
        if saved and self._source in ("auto", saved.get("source")):
            self._cache[key] = saved
            self._set(key, saved, "ready")
            return
        self._set(key, {}, "loading")
        track = dict(st)
        if uri.startswith("yt:track:"):
            track["videoId"] = uri.split(":", 2)[2]
        else:  # e.g. an imported Spotify track, played through its YouTube Music match
            track["videoId"] = (self.player.resolver.cached(uri) or {}).get("v", "")
        source = self._source

        def done(data):
            self._cache[key] = data
            self._set(key, data, "ready")
        def failed(e):  # offline: the lyrics saved with the download, from another source, still help
            if saved:
                self._set(key, saved, "ready")
            else:
                self._set(key, {}, "error")
        self.worker.run(lambda: fetch_lyrics(track, source), done, failed)

    def _on_position(self):
        if not self._synced:
            return
        idx = bisect.bisect_right(self._times, self.player.position + 250) - 1
        if idx != self._current:
            self._current = idx
            self.currentChanged.emit()
