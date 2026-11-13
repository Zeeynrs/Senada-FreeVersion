"""Lyrics from several free sources, chosen in Settings or from the lyrics panel.

  lrclib   LRCLIB (https://lrclib.net), a free public lyrics database
  ytmusic  YouTube Music's own lyrics for the playing video (timed where it has them)
  netease  NetEase Cloud Music, large catalogue of synced LRC files
  auto     the sources above in that order: the first synced lyrics win, otherwise
           the first plain ones
"""

import bisect
import json
import re
import urllib.error
import urllib.parse
import urllib.request

from PySide6.QtCore import Property, QObject, Signal

from . import matching, net, ytmusic

LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
HEADERS = {"User-Agent": "Senada/0.1 (desktop music player)"}

SOURCES = ("auto", "lrclib", "ytmusic", "netease")
AUTO_ORDER = ("lrclib", "ytmusic", "netease")
SOURCE_NAMES = {"lrclib": "LRCLIB", "ytmusic": "YouTube Music", "netease": "NetEase"}


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


FETCHERS = {"lrclib": fetch_lrclib, "ytmusic": fetch_ytmusic, "netease": fetch_netease}


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

    def __init__(self, player, worker, settings, downloads=None, parent=None):
        super().__init__(parent)
        self.downloads = downloads  # lyrics saved with downloaded songs, used without internet
        self.player = player
        self.worker = worker
        self.settings = settings
        self._source = settings["lyrics_source"] if settings["lyrics_source"] in SOURCES else "auto"
        self._cache = {}  # (uri, source) -> result
        self._key = ("", "")
        self._lines = []
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

    def _set(self, key, data, status):
        if key != self._key:
            return
        self._lines = data.get("lines", [])
        self._times = [l["t"] for l in self._lines]
        self._synced = data.get("synced", False)
        self._from = data.get("source", "") if self._lines else ""
        self._offline = bool(data.get("offline")) and bool(self._lines)
        self._status = status if self._lines or status != "ready" else "none"
        self._current = -1
        self.changed.emit()
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
