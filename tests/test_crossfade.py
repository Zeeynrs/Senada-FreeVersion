"""Crossfade between two mpv (run: python -m unittest discover tests)."""

import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import effects as fx
from senada.crossfade import CrossfadeEngine

APP = QCoreApplication.instance() or QCoreApplication([])


class FakeMpv(QObject):
    positionChanged = Signal(int)
    durationChanged = Signal(int)
    stateChanged = Signal(bool)
    trackEnded = Signal()
    loadFailed = Signal()
    errorOccurred = Signal(str)

    def __init__(self, tag):
        super().__init__()
        self.tag, self.calls = tag, []
        self._duration_ms, self._is_playing, self.idle = 200_000, True, False

    def __getattr__(self, name):
        if name.startswith(("play", "queue_next", "pause", "resume", "toggle", "seek", "set_", "stop", "quit")):
            return lambda *a: self.calls.append((name, *a))
        raise AttributeError(name)

    def did(self, name):
        return [c for c in self.calls if c[0] == name]


class Crossfade(unittest.TestCase):
    def setUp(self):
        self.made = []

        def make(tag):
            e = FakeMpv(tag)
            self.made.append(e)
            return e

        self.xf = CrossfadeEngine(make)
        self.a = self.made[0]
        self.events = []
        self.xf.trackEnded.connect(lambda: self.events.append("ended"))
        self.xf.positionChanged.connect(lambda ms: self.events.append(ms))
        self.xf.set_volume(80)

    def test_off_means_gapless_with_one_mpv(self):
        self.xf.queue_next("song2")
        self.a.positionChanged.emit(195_000)
        self.assertEqual(len(self.made), 1)
        self.assertEqual(self.a.did("queue_next")[-1], ("queue_next", "song2"))
        self.assertNotIn("ended", self.events)

    def test_the_next_song_starts_on_the_other_mpv_and_the_volumes_cross(self):
        self.xf.set_tempo(1.25, True)
        self.xf.set_crossfade(6)
        b = self.made[1]
        self.assertIn(("set_tempo", 1.25, True), b.calls)   # the second mpv gets the effects too
        self.xf.queue_next("song2")
        self.assertEqual(self.a.did("queue_next")[-1], ("queue_next", ""))  # not in mpv's playlist
        self.a.positionChanged.emit(190_000)                 # 10 s left: not yet
        self.assertEqual(b.did("play"), [])
        self.a.positionChanged.emit(194_500)                 # 5.5 s left: go
        self.assertEqual(b.did("play"), [("play", "song2")])
        self.assertEqual(self.events, [190_000, "ended"])    # the old position is not passed on
        self.xf.play("song2")                                # the player's own play: already playing
        self.assertEqual(b.did("play"), [("play", "song2")])
        self.a.positionChanged.emit(196_000)                 # the old one is quiet now
        b.positionChanged.emit(1_000)
        self.assertEqual(self.events[-1], 1_000)
        for _ in range(200):
            if self.xf._fading_out is None:
                break
            self.xf._on_fade()
        self.assertEqual(self.a.did("stop"), [("stop",)])
        self.assertEqual(self.a.did("set_volume")[-1], ("set_volume", 0))
        self.assertEqual(b.did("set_volume")[-1], ("set_volume", 80))

    def test_a_seek_finishes_the_fade(self):
        self.xf.set_crossfade(6)
        b = self.made[1]
        self.xf.queue_next("song2")
        self.a.positionChanged.emit(195_000)
        self.xf.seek(30_000)
        self.assertEqual(self.a.did("stop"), [("stop",)])
        self.assertEqual(b.did("seek"), [("seek", 30_000)])
        self.assertEqual(b.did("set_volume")[-1], ("set_volume", 80))

    def test_short_songs_just_end(self):
        self.xf.set_crossfade(6)
        self.a._duration_ms = 20_000
        self.xf.queue_next("song2")
        self.a.positionChanged.emit(18_000)
        self.assertEqual(self.made[1].did("play"), [])

    def test_turning_it_off_hands_the_next_song_back_to_mpv(self):
        self.xf.set_crossfade(4)
        self.xf.queue_next("song2")
        self.xf.set_crossfade(0)
        self.assertEqual(self.a.did("queue_next")[-1], ("queue_next", "song2"))


class Setting(unittest.TestCase):
    def test_kept_with_the_effects(self):
        engine = mock.Mock()
        settings = type("S", (dict,), {"__getitem__": lambda self, k: self.get(k)})()
        effects = fx.AudioEffects(settings, engine)
        engine.set_crossfade.assert_called_with(0)
        effects.setCrossfade(30)
        self.assertEqual(effects.crossfade, fx.CROSSFADE_MAX)
        engine.set_crossfade.assert_called_with(fx.CROSSFADE_MAX)


if __name__ == "__main__":
    unittest.main()
