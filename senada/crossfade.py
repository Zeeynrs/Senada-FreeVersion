"""Crossfade: the next song fades in while the one playing fades out.

One mpv plays one song at a time, so the crossfade uses a second one. CrossfadeEngine is what
the player sees as its audio engine: it has the same methods and signals as AudioEngine and
passes them on from whichever mpv plays the song now ("active"). With the crossfade off (the
default) it is the first mpv alone, gapless as before, and the second mpv is never started.

With it on, the song lined up next (queue_next) is not handed to mpv's playlist; instead,
`seconds` before the end of the song, the other mpv starts it at volume 0 and becomes the
active one: the player hears trackEnded and moves its queue on, and its play() of that same
address finds the song already playing. The volumes then cross over, and the old mpv stops.
A seek, a pause or a new song in the middle of a fade finishes it at once.
"""

import logging

from PySide6.QtCore import QObject, QTimer, Signal

from .engine import AudioEngine

logger = logging.getLogger("senada.crossfade")

MAX_SECONDS = 12
STEP_MS = 50
MIN_SONG_MS = 30_000   # shorter songs just play to the end


class CrossfadeEngine(QObject):
    positionChanged = Signal(int)
    durationChanged = Signal(int)
    stateChanged = Signal(bool)
    trackEnded = Signal()
    loadFailed = Signal()
    errorOccurred = Signal(str)

    def __init__(self, make_engine=None, parent=None):
        super().__init__(parent)
        self._make = make_engine or (lambda tag: AudioEngine(tag=tag))
        self._engines = [self._wire(self._make(""))]
        self._active = self._engines[0]
        self._seconds = 0
        self._next = ""          # the song lined up next, kept here while the crossfade is on
        self._handed = ""        # the address already started on the other mpv (play() of it: no-op)
        self._volume = 80
        self._settings = {}      # the last effects, given to a second mpv when it starts
        self._fading_out = None  # the mpv being faded out
        self._fade_step = 0
        self._fade = QTimer(self, interval=STEP_MS, timeout=self._on_fade)

    def _wire(self, engine):
        for name in ("positionChanged", "durationChanged", "stateChanged", "trackEnded", "loadFailed"):
            getattr(engine, name).connect(lambda *a, e=engine, n=name: self._from(e, n, a))
        engine.errorOccurred.connect(self.errorOccurred)
        return engine

    def _from(self, engine, name, args):
        if engine is not self._active:
            return  # the song fading out says nothing any more
        if name == "positionChanged" and self._check_fade(args[0]):
            return  # the new song took over: the old one's position is not the player's any more
        getattr(self, name).emit(*args)

    # ---- the crossfade --------------------------------------------------------------------------

    @property
    def seconds(self) -> int:
        return self._seconds

    def set_crossfade(self, seconds: int):
        """0: off (gapless); otherwise this many seconds of overlap."""
        seconds = max(0, min(MAX_SECONDS, int(seconds)))
        if seconds == self._seconds:
            return
        self._seconds = seconds
        if seconds:
            self._other()  # the second mpv starts now, so it is ready by the first fade
            self._active.queue_next("")  # the next song waits here instead of in mpv's playlist
        elif self._next:
            self._active.queue_next(self._next)

    def _other(self):
        if len(self._engines) < 2:
            other = self._wire(self._make("b"))
            for method, args in self._settings.items():
                getattr(other, method)(*args)
            other.set_volume(0)
            self._engines.append(other)
        return self._engines[1] if self._active is self._engines[0] else self._engines[0]

    def _check_fade(self, pos_ms) -> bool:
        """Start the crossfade when the song is that close to its end; True if it started."""
        if not self._seconds or not self._next or self._fading_out is not None:
            return False
        duration = getattr(self._active, "_duration_ms", 0)
        fade_ms = self._seconds * 1000
        if duration < max(MIN_SONG_MS, 2 * fade_ms) or duration - pos_ms > fade_ms:
            return False
        if not getattr(self._active, "_is_playing", True):
            return False
        url, self._next = self._next, ""
        old, new = self._active, self._other()
        logger.info("crossfade over %d s", self._seconds)
        new.set_volume(0)
        new.play(url)
        self._handed = url
        self._active = new
        self._fading_out = old
        self._fade_step = 0
        self._fade.start()
        self.trackEnded.emit()   # the player moves on; its play(url) finds the song started
        return True

    def _on_fade(self):
        steps = max(1, self._seconds * 1000 // STEP_MS)
        self._fade_step += 1
        t = min(1.0, self._fade_step / steps)
        if self._fading_out is not None:
            self._fading_out.set_volume(round(self._volume * (1 - t)))
        self._active.set_volume(round(self._volume * t))
        if t >= 1.0:
            self._finish_fade()

    def _finish_fade(self):
        self._fade.stop()
        if self._fading_out is not None:
            self._fading_out.stop()
            self._fading_out = None
        self._active.set_volume(self._volume)

    # ---- AudioEngine's methods -------------------------------------------------------------------

    @property
    def idle(self) -> bool:
        return self._active.idle

    def play(self, url: str):
        if url and url == self._handed:  # started by the crossfade already
            self._handed = ""
            return
        self._handed = ""
        self._finish_fade()
        self._next = ""
        self._active.play(url)

    def queue_next(self, url: str):
        if self._seconds:
            self._next = url
            self._active.queue_next("")
        else:
            self._next = url
            self._active.queue_next(url)

    def pause(self):
        self._finish_fade()
        self._active.pause()

    def resume(self):
        self._active.resume()

    def toggle(self):
        self._finish_fade()
        self._active.toggle()

    def seek(self, ms: int):
        self._finish_fade()
        self._active.seek(ms)

    def set_volume(self, pct: int):
        self._volume = max(0, min(100, int(pct)))
        if not self._fade.isActive():
            self._active.set_volume(self._volume)

    def stop(self):
        self._finish_fade()
        self._handed = self._next = ""
        for e in self._engines:
            e.stop()

    def quit(self):
        self._fade.stop()
        for e in self._engines:
            e.quit()

    def _broadcast(self, method, *args):
        self._settings[method] = args
        for e in self._engines:
            getattr(e, method)(*args)

    def set_tempo(self, speed, keep_pitch):
        self._broadcast("set_tempo", speed, keep_pitch)

    def set_equalizer(self, gains):
        self._broadcast("set_equalizer", gains)

    def set_normalize(self, on):
        self._broadcast("set_normalize", on)

    def set_skip_silence(self, on):
        self._broadcast("set_skip_silence", on)

    def set_position_step(self, ms):
        self._broadcast("set_position_step", ms)
