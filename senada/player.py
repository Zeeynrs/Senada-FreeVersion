"""Playback state and controls using local AudioEngine and AudioResolver."""

import colorsys
import logging
import random
import time

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
from PySide6.QtGui import QImage

from . import net, ytmusic
from .i18n import tr
from .engine import AudioEngine
from .resolver import AudioResolver
from .streams import StreamError, StreamResolver, watch_url

logger = logging.getLogger("senada.player")

DEFAULT_ACCENT = "#d9d9d9"  # neutral until the album art gives a colour


def download(url: str) -> bytes:
    with net.urlopen(url, timeout=10) as resp:
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
    historyChanged = Signal()
    trackMatched = Signal(str, "QVariantMap")  # uri, {imageSmall, image, imageLarge, matchScore}

    def __init__(self, worker, engine: AudioEngine, resolver: AudioResolver, settings, store, catalog, parent=None):
        super().__init__(parent)
        self.store = store
        self.catalog = catalog
        self.worker = worker
        self.engine = engine
        self.resolver = resolver
        self.streams = StreamResolver()
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
        self._play_token = 0  # bumps on every track change; stale stream lookups are dropped
        self._prefetched = ""  # uri already being resolved ahead of time
        self._started = (0, "")  # (play token, video id) of the file last handed to the engine
        self._fallback_token = -1  # play token whose direct stream failed: mpv's yt-dlp hook plays it
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
        self.engine.loadFailed.connect(self._on_load_failed)
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
        self._prefetch_next()  # cheap once the next track is ready

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
            self._play_index(self._queue_index)
        else:
            self.next()

    def _on_load_failed(self):
        """The stream did not open or broke off: play the track through mpv's own yt-dlp hook instead."""
        token, video_id = self._started
        if self._fallback_token == self._play_token:
            if token == self._play_token:  # the fallback failed too
                self.worker.error.emit(tr("Could not play audio: {error}", error=self._state.get("name", "")))
            return
        self._fallback_token = self._play_token
        if token == self._play_token and video_id:  # else the pending lookup starts it as a fallback
            self.streams.forget(video_id)
            self.engine.play(watch_url(video_id))

    def _next_track(self) -> dict | None:
        """The track that plays by itself when the current one ends."""
        if not 0 <= self._queue_index < len(self._queue):
            return None
        if self._state.get("repeat") == "track":
            return self._queue[self._queue_index]
        nxt_idx = self._queue_index + 1
        if nxt_idx >= len(self._queue):
            if self._state.get("repeat") != "context":
                return None
            nxt_idx = 0
        return self._queue[nxt_idx]

    def _resolve(self, track: dict) -> tuple[dict | None, str]:
        """(match, stream address) for a track; blocking. The address is "" when yt-dlp could not get it."""
        info = self.resolver.match(track)
        url = ""
        if info and info.get("v"):
            try:
                url = self.streams.resolve(info["v"])
            except StreamError as e:
                logger.info("no direct stream for %s: %s", info["v"], e)
        return info, url

    def _prefetch_next(self):
        """Look the next track up ahead of time and hand it to the engine for a gapless change.
        Called on every position update, so it must stay cheap when there is nothing to do."""
        track = self._next_track()
        uri = (track or {}).get("uri", "")
        if not uri or self._started[0] != self._play_token:  # nothing next, or a track change is under way
            self.engine.queue_next("")
            return
        video_id = uri.split(":", 2)[2] if uri.startswith("yt:track:") else (self.resolver.cached(uri) or {}).get("v")
        url = self.streams.cached(video_id) if video_id else None
        if url:
            self.engine.queue_next(url)
        elif uri != self._prefetched:  # only one lookup per track
            self._prefetched = uri
            self.engine.queue_next("")
            self.worker.run(lambda: self._resolve(track),
                            lambda found: self._apply_match(track, found[0]),
                            lambda e: None)

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
        self._play_token += 1
        token = self._play_token
        self._state = {
            **self._state,
            **track,
            "hasTrack": True,
            "isPlaying": True,
            "liked": self.store.is_liked(track.get("uri", "")),
        }
        self.stateChanged.emit()
        self.positionChanged.emit()
        self.trackChanged.emit()
        self.queueChanged.emit()

        self._on_track_changed(track)

        # Resolve stream URL and play (imported tracks are matched to a YouTube Music upload first)
        def on_resolved(found):
            info, url = found
            if token != self._play_token:
                return  # the user already moved on to another track
            if info and info.get("v"):
                self._apply_match(track, info)
                self._started = (token, info["v"])
                if not url or self._fallback_token == token:
                    self.streams.forget(info["v"])
                    url = watch_url(info["v"])  # slower: mpv's yt-dlp hook looks the stream up
                self.engine.play(url)
            else:
                self.worker.error.emit(tr("Not found on YouTube Music: {name} — try right-click → Pick another version", name=track.get("name")))
                self.next()

        def on_fail(e):
            if token == self._play_token:
                self.worker.error.emit(tr("Could not play audio: {error}", error=e))

        self.worker.run(lambda: self._resolve(track), on_resolved, on_fail)

    def _apply_match(self, track: dict, info: dict | None):
        """Give an imported (metadata-only) track the cover and confidence of its match."""
        uri = track.get("uri", "")
        if not info or uri.startswith("yt:track:"):
            return
        patch = {k: info.get(k) for k in ("imageSmall", "image", "imageLarge") if info.get(k)}
        patch["matchScore"] = info.get("s", 0)
        def fill(t):  # the match score always; covers only where the track has none (keep Spotify art)
            t.update({k: v for k, v in patch.items() if k == "matchScore" or not t.get(k)})
        for t in [self._track_cache.get(uri)] + [q for q in self._queue if q.get("uri") == uri]:
            if t is not None:
                fill(t)
        if self._state.get("uri") == uri:
            first_cover = not self._state.get("imageSmall") and patch.get("imageSmall")
            fill(self._state)
            self.stateChanged.emit()
            if first_cover:
                self._on_cover(patch["imageSmall"])
        self.trackMatched.emit(uri, patch)

    def replaceMatch(self, uri: str, patch: dict):
        """A different upload was picked for this track: update it and restart it if it is playing."""
        for t in [self._track_cache.get(uri)] + [q for q in self._queue if q.get("uri") == uri]:
            if t is not None:
                t.update(patch)
        if self._state.get("uri") == uri and 0 <= self._queue_index < len(self._queue):
            self._play_index(self._queue_index)

    def _on_cover(self, art: str):
        self.worker.run(lambda: download(art), lambda data: self._set_accent(accent_from_image(data)), lambda e: None)

    def _on_track_changed(self, track: dict):
        if not track.get("uri"):
            return
        self.store.add_history(track)
        self.historyChanged.emit()

        art = track.get("imageSmall")
        if art:
            self.worker.run(
                lambda: download(art),
                lambda data: self._set_accent(accent_from_image(data)),
                lambda e: None
            )

    def _set_accent(self, color):
        if color != self._accent:
            self._accent = color
            self.accentChanged.emit()

    def cache_tracks(self, tracks: list):
        for t in tracks or []:
            if isinstance(t, dict) and t.get("uri"):
                self._track_cache[t["uri"]] = t

    def _lookup(self, uri: str) -> dict | None:
        """Track metadata for a URI: from what the pages showed, else from YouTube Music."""
        t = self._track_cache.get(uri)
        if t is None and uri.startswith("yt:track:"):
            t = ytmusic.track(uri.split(":", 2)[2])
            if t:
                self._track_cache[uri] = t
        return t

    def _start_queue(self, tracks: list, index: int = 0, context_uri: str = ""):
        if not tracks:
            self.worker.error.emit(tr("No songs that can be played"))
            return
        self._queue = list(tracks)
        self._state["contextUri"] = context_uri
        self._play_index(min(max(0, index), len(self._queue) - 1))

    @Slot("QVariantList", int)
    def playUris(self, uris, index=0):
        uris = [u for u in uris if u]
        if not uris:
            return
        target = uris[index] if 0 <= index < len(uris) else uris[0]

        def fetch_tracks():
            tracks = []
            for u in uris:
                try:
                    t = self._lookup(u)
                except ytmusic.YTMusicError:
                    t = None
                if t:
                    tracks.append(t)
            return tracks

        def on_done(tracks):
            idx = next((i for i, t in enumerate(tracks) if t.get("uri") == target), 0)
            self._start_queue(tracks, idx)

        self.worker.run(fetch_tracks, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str, str)
    def playContext(self, context_uri, offset_uri=""):
        def fetch_context():
            tracks = self.catalog.tracks_for(context_uri)
            self.cache_tracks(tracks)
            return tracks

        def on_done(tracks):
            idx = next((i for i, t in enumerate(tracks) if offset_uri and t.get("uri") == offset_uri), 0)
            if self._state.get("shuffle") and tracks and not offset_uri:
                tracks = list(tracks)
                random.shuffle(tracks)
            self._start_queue(tracks, idx, context_uri)

        self.worker.run(fetch_context, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str)
    def shufflePlay(self, context_uri):
        self._state["shuffle"] = True
        self.stateChanged.emit()

        def fetch_and_shuffle():
            tracks = list(self.catalog.tracks_for(context_uri))
            self.cache_tracks(tracks)
            random.shuffle(tracks)
            return tracks

        self.worker.run(fetch_and_shuffle, lambda tracks: self._start_queue(tracks, 0, context_uri),
                        lambda e: self.worker.error.emit(str(e)))

    @Slot(str)
    def playRadio(self, uri):
        """Play a track followed by YouTube Music's radio for it."""
        if not uri.startswith("yt:track:"):
            seed = self._track_cache.get(uri)
            if not seed:
                return

            def find_seed():
                hits = ytmusic.search(f"{seed.get('artists', '')} {seed.get('name', '')}").get("tracks") or []
                return ytmusic.up_next(hits[0]["id"]) if hits else []
            fetch = find_seed
        else:
            fetch = lambda: ytmusic.up_next(uri.split(":", 2)[2])

        def on_done(tracks):
            self.cache_tracks(tracks)
            self._start_queue(tracks, 0, "")

        self.worker.run(fetch, on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot(str)
    def addToQueue(self, uri):
        def on_done(t):
            if t:
                self._queue.append(t)
                self.queueChanged.emit()
                self.worker.error.emit(tr("Added to queue"))

        self.worker.run(lambda: self._lookup(uri), on_done, lambda e: self.worker.error.emit(str(e)))

    @Slot()
    def toggleLike(self):
        uri = self._state.get("uri")
        if uri:
            self.setLiked(uri, not self._state.get("liked"))

    @Slot(str, bool)
    def setLiked(self, uri, liked):
        track = self._track_cache.get(uri)
        if track is None and uri == self._state.get("uri"):
            track = {k: self._state.get(k) for k in ("uri", "id", "name", "artists", "artistId", "album",
                                                      "albumId", "imageSmall", "image", "imageLarge",
                                                      "durationMs", "explicit")}
        if not track:
            return
        if uri == self._state.get("uri"):
            self._state["liked"] = liked
            self.stateChanged.emit()
        if self.store.set_liked(track, liked):
            self.likedChanged.emit(uri, liked)
            self.worker.error.emit(tr("Saved to Liked Songs") if liked else tr("Removed from Liked Songs"))

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
