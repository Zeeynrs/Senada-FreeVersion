"""Sleep timer: the music stops by itself after a while, or when the song that is playing ends.

Not saved: a timer set last night should not stop the music today. The last seconds fade the
volume out so the song does not cut off mid-note; once it is paused the volume is put back,
so the next play starts at the usual level. The player bar sets it (qml/SleepTimerButton.qml).
"""

import time

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

MINUTES = (15, 30, 45, 60, 90, 120)  # the choices in the menu
FADE_MS = 8000
FADE_STEPS = 32


class SleepTimer(QObject):
    changed = Signal()

    def __init__(self, engine, volume, is_playing, parent=None):
        """engine: pause() and set_volume(pct); volume(): the volume the user chose;
        is_playing(): whether there is music to stop."""
        super().__init__(parent)
        self.engine = engine
        self._volume = volume
        self._is_playing = is_playing
        self._mode = "off"  # "off", "time" (ends at _ends_at), "track" (the current song ends)
        self._ends_at = 0.0  # time.time() when the music stops
        self._fade_from = 0
        self._step = 0
        self._timer = QTimer(self, singleShot=True, timeout=self._start_fade)
        self._fade = QTimer(self, interval=FADE_MS // FADE_STEPS, timeout=self._fade_step)

    # ---- QML ------------------------------------------------------------------------

    @Property(str, notify=changed)
    def mode(self):
        return self._mode

    @Property(float, notify=changed)
    def endsAt(self):
        """When the music stops, in ms since the epoch like QML's Date.now() (0 unless "time")."""
        return self._ends_at * 1000 if self._mode == "time" else 0.0

    @Property("QVariantList", constant=True)
    def choices(self):
        return list(MINUTES)

    @Slot(int)
    def start(self, minutes):
        """Stop the music in this many minutes (0 or less: switch the timer off)."""
        self._cancel()
        if minutes > 0:
            self._mode = "time"
            self._ends_at = time.time() + minutes * 60
            self._timer.start(max(0, minutes * 60_000 - FADE_MS))
        self.changed.emit()

    @Slot()
    def stopAfterTrack(self):
        self._cancel()
        self._mode = "track"
        self.changed.emit()

    @Slot()
    def cancel(self):
        if self._mode != "off":
            self._cancel()
            self.changed.emit()

    # ---- the player ----------------------------------------------------------------

    @property
    def stops_after_track(self) -> bool:
        return self._mode == "track"

    def track_ended(self):
        """The song ended while the timer waited for it: the timer is used up."""
        if self._mode == "track":
            self._mode = "off"
            self.changed.emit()

    # ---- inside ---------------------------------------------------------------------

    def _cancel(self):
        self._timer.stop()
        if self._fade.isActive():  # stopped halfway through the fade: the volume comes back
            self._fade.stop()
            self.engine.set_volume(self._volume())
        self._mode = "off"
        self._ends_at = 0.0

    def _start_fade(self):
        if not self._is_playing():  # already quiet: nothing to fade
            self._finish()
            return
        self._fade_from = self._volume()
        self._step = 0
        self._fade.start()

    def _fade_step(self):
        self._step += 1
        if self._step >= FADE_STEPS:
            self._fade.stop()
            self.engine.pause()
            self.engine.set_volume(self._volume())
            self._finish()
            return
        self.engine.set_volume(round(self._fade_from * (1 - self._step / FADE_STEPS)))

    def _finish(self):
        self._mode = "off"
        self._ends_at = 0.0
        self.changed.emit()
