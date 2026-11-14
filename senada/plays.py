"""What was listened to, and for how long: the one place that watches songs come and go.

The listening statistics (stats.py) and scrobbling (scrobble.py) both build on it. Time counts
only while a song plays and moves on by itself: a seek or a jump is not listening.
"""

import time

from PySide6.QtCore import QObject, Signal

TRACK_KEYS = ("uri", "name", "artists", "album", "durationMs", "imageSmall", "image")
MAX_STEP_MS = 3000  # a bigger jump in position is a seek, not listening


class PlayTracker(QObject):
    started = Signal("QVariantMap")                # a song began playing (now playing)
    finished = Signal("QVariantMap", int, float)   # the song, ms listened, when it began (epoch seconds)

    def __init__(self, player, parent=None):
        super().__init__(parent)
        self.player = player
        self._track = None
        self._listened = 0
        self._started_at = 0.0
        self._last_pos = None
        player.trackChanged.connect(self._on_track)
        player.positionChanged.connect(self._on_position)

    def _on_track(self):
        self.flush()
        s = self.player.state
        if not (s.get("hasTrack") and s.get("uri")):
            return
        self._track = {k: s.get(k) for k in TRACK_KEYS}
        self._started_at = time.time()
        self._listened = 0
        self._last_pos = self.player.position
        self.started.emit(dict(self._track))

    def _on_position(self):
        pos = self.player.position
        s = self.player.state
        if self._track is not None and not self._track.get("durationMs") and s.get("uri") == self._track["uri"]:
            self._track["durationMs"] = s.get("durationMs") or 0  # mpv tells the length once it plays
        if self._track is not None and s.get("isPlaying") and self._last_pos is not None:
            step = pos - self._last_pos
            if 0 < step <= MAX_STEP_MS:
                self._listened += step
        self._last_pos = pos

    def flush(self):
        """The song is over (another began, or Senada is quitting): report how much was heard."""
        if self._track is not None and self._listened > 0:
            self.finished.emit(dict(self._track), int(self._listened), self._started_at)
        self._track = None
        self._listened = 0
