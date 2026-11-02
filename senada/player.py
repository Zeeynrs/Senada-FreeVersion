"""Playback state and controls using local AudioEngine and AudioResolver."""

import colorsys
import random
import time
import urllib.request

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
from PySide6.QtGui import QImage

from . import api as sp
from .engine import AudioEngine
from .resolver import AudioResolver

DEFAULT_ACCENT = "#9ecaff"


def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=10) as resp:
        return resp.read()


def accent_from_image(data: bytes) -> str:
    """Pick a lively, readable-on-dark colour from album art.
    Runs on the UI thread: PySide6 types are not safe to first-use from worker threads.
    """
    img = QImage.fromData(data)
    if img.isNull():
        return DEFAULT_ACCENT
    img = img.scaled(24, 24)
    bins = [[0.0, 0.0, 0.0, 0.0] for _ in range(12)]  # weight, r, g, b
    for y in range(img.height()):
        for x in range(img.width()):
            c = img.pixelColor(x, y)
            r, g, b = c.redF(), c.greenF(), c.blueF()
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            w = s * s * v + 0.002
            slot = bins[int(h * 12) % 12]
            slot[0] += w
            slot[1] += r * w
            slot[2] += g * w
            slot[3] += b * w
    w, r, g, b = max(bins, key=lambda b: b[0])
    h, s, v = colorsys.rgb_to_hsv(r / w, g / w, b / w)
    s = min(max(s, 0.35), 0.75) if s > 0.08 else s
    v = max(v, 0.82)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


class Player(QObject):
    stateChanged = Signal()
    positionChanged = Signal()
    devicesChanged = Signal()
    queueChanged = Signal()
    accentChanged = Signal()
    trackChanged = Signal()
    likedChanged = Signal(str, bool)

    def __init__(self, api: sp.SpotifyApi, worker, engine: AudioEngine, resolver: AudioResolver, settings, parent=None):
        super().__init__(parent)
        self.api = api
        self.worker = worker
        self.engine = engine
        self.resolver = resolver
        self.settings = settings

        self._state = {
            "hasTrack": False,
            "isPlaying": False,
            "shuffle": False,
            "repeat": "off",  # 'off', 'context', 'track'
            "volume": 80,
            "supportsVolume": True,
            "deviceId": "local",
            "deviceName": "Senada (Lokal)",
            "deviceType": "computer",
            "contextUri": "",
            "liked": False,
            "durationMs": 0,
        }
        self._accent = DEFAULT_ACCENT
        self._position = 0
        self._queue = []
        self._queue_index = -1
        self._track_cache = {}  # uri -> track_dict
        self._devices = [{
            "id": "local",
            "name": "Senada (Lokal)",
            "type": "computer",
            "active": True,
            "volume": 80,
            "local": True,
            "restricted": False,
        }]

        # Connect audio engine signals
        self.engine.positionChanged.connect(self._on_engine_pos)
        self.engine.durationChanged.connect(self._on_engine_duration)
        self.engine.stateChanged.connect(self._on_engine_state)
        self.engine.trackEnded.connect(self._on_track_ended)
        self.engine.errorOccurred.connect(lambda msg: self.worker.error.emit(msg))

        # Initial volume
        self.engine.set_volume(80)

    # ---- properties for QML ---------------------------------------------

    @Property("QVariantMap", notify=stateChanged)
    def state(self):
        return self._state

    @Property(int, notify=positionChanged)
    def position(self):
        return self._position

    @Property("QVariantList", notify=devicesChanged)
    def devices(self):
        return self._devices

    @Property("QVariantList", notify=queueChanged)
    def queue(self):
        # Expose queue tracks after current index
        if self._queue_index >= 0 and self._queue_index + 1 < len(self._queue):
            return self._queue[self._queue_index + 1:]
        return []

    @Property(str, notify=accentChanged)
    def accent(self):
        return self._accent

    # ---- playback engine callbacks --------------------------------------

    def _on_engine_pos(self, pos_ms: int):
        self._position = pos_ms
        self.positionChanged.emit()

        # Pre-fetch next track when reaching last 15 seconds
        dur = self._state.get("durationMs", 0)
        if dur > 20000 and (dur - pos_ms) < 15000:
            self._prefetch_next()

    def _on_engine_duration(self, dur_ms: int):
        if dur_ms > 0 and abs(dur_ms - self._state.get("durationMs", 0)) > 2000:
            self._state["durationMs"] = dur_ms
            self.stateChanged.emit()

    def _on_engine_state(self, is_playing: bool):
        if self._state.get("isPlaying") != is_playing:
            self._state["isPlaying"] = is_playing
            self.stateChanged.emit()

    def _on_track_ended(self):
        if self._state.get("repeat") == "track":
            self.seek(0)
            self.engine.resume()
        else:
            self.next()

    def _prefetch_next(self):
        nxt_idx = self._queue_index + 1
        if self._state.get("repeat") == "context" and nxt_idx >= len(self._queue) and len(self._queue) > 0:
            nxt_idx = 0
        if 0 <= nxt_idx < len(self._queue):
            nxt_track = self._queue[nxt_idx]
            self.worker.run(
                lambda: self.resolver.resolve(
                    nxt_track.get("uri", ""),
                    nxt_track.get("name", ""),
                    nxt_track.get("artists", ""),
                    nxt_track.get("durationMs", 0)
                ),
                lambda _: None,
                lambda e: None
            )

    # ---- controls -------------------------------------------------------

    def start(self):
        self.refreshDevices()

    def stop(self):
        self.engine.stop()
        self._state["isPlaying"] = False
        self.stateChanged.emit()

    @Slot(bool)
    def setFastPolling(self, _):
        pass

    @Slot()
    def refresh(self):
        pass

    @Slot()
    def togglePlay(self):
        if not self._state.get("hasTrack"):
            if self._queue:
                self._play_index(max(0, self._queue_index))
            return
        self.engine.toggle()

    @Slot()
    def next(self):
        if not self._queue:
            return
        if self._queue_index + 1 < len(self._queue):
            self._play_index(self._queue_index + 1)
        elif self._state.get("repeat") == "context":
            self._play_index(0)
        else:
            self.engine.stop()
            self._state["isPlaying"] = False
            self.stateChanged.emit()

    @Slot(int)
    def skip(self, count):
        target = self._queue_index + max(1, count)
        if target < len(self._queue):
            self._play_index(target)

    @Slot()
    def previous(self):
        if self._position > 4000:
            self.seek(0)
        elif self._queue_index > 0:
            self._play_index(self._queue_index - 1)
        else:
            self.seek(0)

    @Slot(int)
    def seek(self, ms):
        self._position = max(0, int(ms))
        self.positionChanged.emit()
        self.engine.seek(self._position)

    @Slot(int)
    def setVolume(self, pct):
        pct = max(0, min(100, int(pct)))
        self._state["volume"] = pct
        self._devices[0]["volume"] = pct
        self.engine.set_volume(pct)
        self.stateChanged.emit()

    @Slot()
    def toggleShuffle(self):
        new_val = not self._state.get("shuffle")
        self._state["shuffle"] = new_val
        self.stateChanged.emit()

        if new_val and self._queue:
            current = self._queue[self._queue_index] if 0 <= self._queue_index < len(self._queue) else None
            remaining = [t for i, t in enumerate(self._queue) if i != self._queue_index]
            random.shuffle(remaining)
            self._queue = ([current] if current else []) + remaining
            self._queue_index = 0
            self.queueChanged.emit()

    @Slot()
    def cycleRepeat(self):
        nxt = {"off": "context", "context": "track", "track": "off"}[self._state.get("repeat", "off")]
        self._state["repeat"] = nxt
        self.stateChanged.emit()

    # ---- play contexts & queues -----------------------------------------

    def _play_index(self, index: int):
        if index < 0 or index >= len(self._queue):
            return
        self._queue_index = index
        track = self._queue[index]
        self._position = 0
        self._state = {
            **self._state,
            **track,
            "hasTrack": True,
            "isPlaying": True,
        }
        self.stateChanged.emit()
        self.positionChanged.emit()
        self.trackChanged.emit()
        self.queueChanged.emit()

        # Update accent and check liked
        self._on_track_changed(track)

        # Resolve stream URL and play
        def do_resolve():
            return self.resolver.resolve(
                track.get("uri", ""),
                track.get("name", ""),
                track.get("artists", ""),
                track.get("durationMs", 0)
            )

        def on_resolved(stream_url):
            if stream_url:
                self.engine.play(stream_url)
            else:
                self.worker.error.emit(f"Audio tidak ditemukan: {track.get('name')}")
                self.next()

        def on_fail(e):
            self.worker.error.emit(f"Gagal memutar audio: {e}")

        self.worker.run(do_resolve, on_resolved, on_fail)

    def _on_track_changed(self, track: dict):
        uri = track.get("uri")
        if not uri:
            return

        # Check library contains
        self.worker.run(
            lambda: self.api.get("/me/library/contains", uris=uri),
            lambda res: self._patch_liked(bool(res and res[0])) if self._state.get("uri") == uri else None,
            lambda e: None
        )

        art = track.get("imageSmall")
        if art:
            self.worker.run(
                lambda: download(art),
                lambda data: self._set_accent(accent_from_image(data)),
                lambda e: None
            )

    def _patch_liked(self, liked: bool):
        self._state["liked"] = liked
        self.stateChanged.emit()

    def _set_accent(self, color):
        if color != self._accent:
            self._accent = color
            self.accentChanged.emit()

    @Slot("QVariantList", int)
    def playUris(self, uris, index=0):
        uris = [u for u in uris if u]
        if not uris:
            return

        def fetch_tracks():
            # If tracks are already cached
            missing_ids = []
            result_tracks = []
            for u in uris:
                if u in self._track_cache:
                    result_tracks.append(self._track_cache[u])
                else:
                    tid = u.split(":")[-1]
                    missing_ids.append(tid)

            if missing_ids:
                # Fetch in chunks of 50
                for i in range(0, len(missing_ids), 50):
                    chunk = missing_ids[i:i + 50]
                    res = self.api.get("/tracks", ids=",".join(chunk))
                    for item in (res or {}).get("tracks") or []:
                        t = sp.track(item)
                        if t:
                            self._track_cache[t["uri"]] = t

            return [self._track_cache.get(u) for u in uris if self._track_cache.get(u)]

        def on_done(tracks):
            if not tracks:
                return
            self._queue = tracks
            target_index = min(max(0, index), len(tracks) - 1)
            self._play_index(target_index)

        self.worker.run(fetch_tracks, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str, str)
    def playContext(self, context_uri, offset_uri=""):
        def fetch_context():
            parts = context_uri.split(":")
            if len(parts) < 3:
                return []
            kind, item_id = parts[1], parts[2]
            tracks = []
            if kind == "playlist":
                items = self.api.paged(f"/playlists/{item_id}/tracks", max_items=500, limit=50)
                tracks = [t for t in (sp.wrapped_track(x) for x in items) if t]
            elif kind == "album":
                alb = self.api.get(f"/albums/{item_id}") or {}
                items = self.api.paged(f"/albums/{item_id}/tracks", max_items=200, limit=50)
                tracks = [t for t in (sp.track(x, album=alb) for x in items) if t]
            elif kind == "artist":
                res = self.api.get(f"/artists/{item_id}/top-tracks") or {}
                tracks = [t for t in (sp.track(x) for x in res.get("tracks", [])) if t]
            for t in tracks:
                self._track_cache[t["uri"]] = t
            return tracks

        def on_done(tracks):
            if not tracks:
                return
            self._queue = tracks
            self._state["contextUri"] = context_uri
            idx = 0
            if offset_uri:
                for i, t in enumerate(tracks):
                    if t.get("uri") == offset_uri:
                        idx = i
                        break
            self._play_index(idx)

        self.worker.run(fetch_context, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str)
    def shufflePlay(self, context_uri):
        self._state["shuffle"] = True
        self.stateChanged.emit()

        def fetch_and_shuffle():
            parts = context_uri.split(":")
            if len(parts) < 3:
                return []
            kind, item_id = parts[1], parts[2]
            tracks = []
            if kind == "playlist":
                items = self.api.paged(f"/playlists/{item_id}/tracks", max_items=500, limit=50)
                tracks = [t for t in (sp.wrapped_track(x) for x in items) if t]
            elif kind == "album":
                alb = self.api.get(f"/albums/{item_id}") or {}
                items = self.api.paged(f"/albums/{item_id}/tracks", max_items=200, limit=50)
                tracks = [t for t in (sp.track(x, album=alb) for x in items) if t]
            elif kind == "artist":
                res = self.api.get(f"/artists/{item_id}/top-tracks") or {}
                tracks = [t for t in (sp.track(x) for x in res.get("tracks", [])) if t]
            for t in tracks:
                self._track_cache[t["uri"]] = t
            random.shuffle(tracks)
            return tracks

        def on_done(tracks):
            if not tracks:
                return
            self._queue = tracks
            self._state["contextUri"] = context_uri
            self._play_index(0)

        self.worker.run(fetch_and_shuffle, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str)
    def addToQueue(self, uri):
        def fetch_one():
            if uri in self._track_cache:
                return self._track_cache[uri]
            tid = uri.split(":")[-1]
            res = self.api.get(f"/tracks/{tid}")
            t = sp.track(res)
            if t:
                self._track_cache[uri] = t
            return t

        def on_done(t):
            if t:
                self._queue.append(t)
                self.queueChanged.emit()
                self.worker.error.emit("Ditambahkan ke antrean")

        self.worker.run(fetch_one, on_done, lambda e: None)

    @Slot()
    def toggleLike(self):
        uri = self._state.get("uri")
        if uri:
            self.setLiked(uri, not self._state.get("liked"))

    @Slot(str, bool)
    def setLiked(self, uri, liked):
        if uri == self._state.get("uri"):
            self._state["liked"] = liked
            self.stateChanged.emit()
        self.worker.run(
            lambda: self.api.request("PUT" if liked else "DELETE", "/me/library", {"uris": uri}),
            lambda _: self.likedChanged.emit(uri, liked),
            lambda e: None
        )

    # ---- devices & queue --------------------------------------------------

    @Slot()
    def refreshDevices(self):
        self.devicesChanged.emit()

    @Slot(str)
    def transfer(self, device_id):
        pass

    @Slot()
    def refreshQueue(self):
        self.queueChanged.emit()
