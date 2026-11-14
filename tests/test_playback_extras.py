"""Even loudness, skipping silence, the sleep timer and one Senada at a time
(run: python -m unittest discover tests)."""

import os
import subprocess
import sys
import time
import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication

from senada import effects as fx
from senada.config import NO_WINDOW
from senada.engine import (EQ_LABEL, NORM_GRAPH, NORM_LABEL, SILENCE_GRAPH, SILENCE_LABEL, SKIP_SPEED, AudioEngine,
                           eq_graph, filter_chain, find_tool)
from senada.instance import Instance, ask_running_to_show
from senada.player import Player
from senada.sleep import FADE_STEPS, SleepTimer
from tests.test_recovery import FakeEngine, FakeResolver, FakeStore, FakeStreams, SyncWorker, song

APP = QCoreApplication.instance() or QCoreApplication([])
EQ = [6, 0, 0, 0, 0, 0]


def engine():
    with mock.patch.object(AudioEngine, "_start_mpv"), mock.patch("atexit.register"):
        e = AudioEngine()
    sent = []
    e._send_command = sent.append
    return e, sent


def silence_starts(e):
    e._handle_message({"event": "property-change", "name": f"af-metadata/{SILENCE_LABEL}",
                       "data": {"lavfi.silence_start": "3"}})


def silence_ends(e):
    e._handle_message({"event": "property-change", "name": f"af-metadata/{SILENCE_LABEL}",
                       "data": {"lavfi.silence_start": "3", "lavfi.silence_end": "7", "lavfi.silence_duration": "4"}})


class FilterChain(unittest.TestCase):
    def test_silence_is_looked_for_first_and_the_equalizer_comes_last(self):
        chain = filter_chain(True, True, EQ)
        self.assertEqual(chain, f"@{SILENCE_LABEL}:lavfi=[{SILENCE_GRAPH}],@{NORM_LABEL}:lavfi=[{NORM_GRAPH}],"
                                f"@{EQ_LABEL}:lavfi=[{eq_graph(EQ)}]")

    def test_nothing_on_means_no_filter(self):
        self.assertEqual(filter_chain(False, False, None), "")

    def test_switching_loudness_on_and_off(self):
        e, sent = engine()
        e.set_normalize(True)
        self.assertEqual(sent, [["af", "set", f"@{NORM_LABEL}:lavfi=[{NORM_GRAPH}]"]])
        e.set_normalize(True)  # no change: nothing sent
        self.assertEqual(len(sent), 1)
        e.set_normalize(False)
        self.assertEqual(sent[-1], ["af", "clr", ""])

    def test_equalizer_off_keeps_the_other_filters(self):
        e, sent = engine()
        e.set_normalize(True)
        e.set_equalizer(EQ)
        e.set_equalizer(None)
        self.assertEqual(sent[-1], ["af", "set", f"@{NORM_LABEL}:lavfi=[{NORM_GRAPH}]"])

    def test_equalizer_gains_still_go_to_the_running_filter(self):
        e, sent = engine()
        e.set_skip_silence(True)
        e.set_equalizer(EQ)
        sent.clear()
        e.set_equalizer([1, 2, 3, 4, 5, 6])
        self.assertTrue(sent and all(c[0] == "af-command" for c in sent))

    def test_a_new_mpv_gets_every_filter_again(self):
        e, sent = engine()
        e.set_normalize(True)
        e.set_skip_silence(True)
        sent.clear()
        e._on_connected()
        self.assertIn(["observe_property", 5, f"af-metadata/{SILENCE_LABEL}"], sent)
        self.assertIn(["set_property", "media-controls", False], sent)  # Senada owns the media keys
        self.assertIn(["af", "set", filter_chain(True, True, None)], sent)


class SkipSilence(unittest.TestCase):
    def setUp(self):
        self.e, self.sent = engine()
        self.e.set_tempo(1.25, True)
        self.e.set_skip_silence(True)
        self.sent.clear()

    def test_a_silence_plays_fast_and_the_song_at_its_own_tempo_after(self):
        silence_starts(self.e)
        self.assertEqual(self.sent, [["set_property", "speed", SKIP_SPEED]])
        silence_ends(self.e)
        self.assertEqual(self.sent[-1], ["set_property", "speed", 1.25])

    def test_nothing_happens_while_switched_off(self):
        self.e.set_skip_silence(False)
        self.sent.clear()
        silence_starts(self.e)
        self.assertEqual(self.sent, [])

    def test_switching_off_in_a_silence_brings_the_tempo_back(self):
        silence_starts(self.e)
        self.e.set_skip_silence(False)
        self.assertIn(["set_property", "speed", 1.25], self.sent)

    def test_a_seek_or_the_next_song_ends_the_skip(self):
        for event in ({"event": "playback-restart"}, {"event": "end-file", "reason": "eof"}):
            silence_starts(self.e)
            self.sent.clear()
            self.e._handle_message(event)
            self.assertEqual(self.sent, [["set_property", "speed", 1.25]], event)

    def test_a_new_tempo_during_a_skip_wins(self):
        silence_starts(self.e)
        self.e.set_tempo(1.5, True)
        self.sent.clear()
        silence_ends(self.e)
        self.assertEqual(self.sent, [])  # already at the chosen tempo


class EffectsSettings(unittest.TestCase):
    def test_off_by_default_and_kept(self):
        settings, eng = {}, mock.Mock()
        settings_obj = type("S", (dict,), {"__getitem__": lambda self, k: self.get(k)})(settings)
        effects = fx.AudioEffects(settings_obj, eng)
        eng.set_normalize.assert_called_with(False)
        eng.set_skip_silence.assert_called_with(False)
        effects.setNormalize(True)
        effects.setSkipSilence(True)
        eng.set_normalize.assert_called_with(True)
        eng.set_skip_silence.assert_called_with(True)
        effects._save()
        again = fx.AudioEffects(settings_obj, mock.Mock())
        self.assertTrue(again.normalize and again.skipSilence)


class SleepEngine:
    def __init__(self):
        self.volumes, self.paused = [], 0

    def set_volume(self, v):
        self.volumes.append(v)

    def pause(self):
        self.paused += 1


class Sleep(unittest.TestCase):
    def setUp(self):
        self.engine, self.playing = SleepEngine(), True
        self.timer = SleepTimer(self.engine, lambda: 80, lambda: self.playing)

    def test_minutes_from_now(self):
        self.timer.start(30)
        self.assertEqual(self.timer.mode, "time")
        self.assertAlmostEqual(self.timer.endsAt / 1000, time.time() + 1800, delta=2)
        self.timer.cancel()
        self.assertEqual((self.timer.mode, self.timer.endsAt), ("off", 0))

    def test_the_end_fades_out_pauses_and_puts_the_volume_back(self):
        self.timer.start(15)
        self.timer._start_fade()
        for _ in range(FADE_STEPS):
            self.timer._fade_step()
        self.assertEqual(self.engine.paused, 1)
        self.assertLess(min(self.engine.volumes), 10)
        self.assertEqual(self.engine.volumes[-1], 80)
        self.assertEqual(self.timer.mode, "off")

    def test_cancelling_halfway_through_the_fade_restores_the_volume(self):
        self.timer.start(15)
        self.timer._start_fade()
        self.timer._fade_step()
        self.timer.cancel()
        self.assertEqual((self.engine.volumes[-1], self.engine.paused), (80, 0))

    def test_nothing_playing_means_nothing_to_fade(self):
        self.playing = False
        self.timer.start(15)
        self.timer._start_fade()
        self.assertEqual((self.engine.volumes, self.engine.paused, self.timer.mode), ([], 0, "off"))


class IdleEngine(FakeEngine):
    def __init__(self):
        super().__init__()
        self.idle = False
        self.queued = []

    def queue_next(self, url):
        self.queued.append(url)

    def toggle(self):
        pass

    def pause(self):
        pass


class SleepAfterThisSong(unittest.TestCase):
    def setUp(self):
        self.engine = IdleEngine()
        matches = {f"spotify:track:{n}": {"v": f"v{n}", "s": 100} for n in (1, 2)}
        self.player = Player(SyncWorker(), self.engine, FakeResolver(matches), {}, FakeStore(), None)
        self.player.streams = FakeStreams({"v1": "https://audio/1", "v2": "https://audio/2"})
        self.player._queue = [song(1), song(2)]
        self.player._play_index(0)

    def test_stops_at_the_song_end_and_play_goes_on_with_the_next(self):
        self.player.sleep.stopAfterTrack()
        self.assertIsNone(self.player._next_track())  # nothing lined up for a gapless change
        self.assertEqual(self.engine.queued[-1], "")
        self.engine.idle = True  # mpv stopped at the end of the file
        self.engine.trackEnded.emit()
        self.assertFalse(self.player.state["isPlaying"])
        self.assertEqual(self.player.sleep.mode, "off")
        self.player.togglePlay()
        self.assertEqual(self.engine.played[-1], "https://audio/2")


SECOND_SENADA = """
import sys
from PySide6.QtCore import QCoreApplication
app = QCoreApplication([])
from senada.instance import ask_running_to_show
sys.exit(0 if ask_running_to_show(sys.argv[1]) else 3)
"""


class OneSenada(unittest.TestCase):
    def second_start(self, name):
        """Another process, like Senada started again from the Start menu (in the same thread
        the blocking connect would wait on a server that can't answer)."""
        proc = subprocess.Popen([sys.executable, "-c", SECOND_SENADA, name], creationflags=NO_WINDOW)
        deadline = time.time() + 10
        while proc.poll() is None and time.time() < deadline:
            APP.processEvents()
            time.sleep(0.01)
        return proc.wait(timeout=5) == 0

    def test_a_second_start_asks_the_first_to_show(self):
        name = f"senada-test-{os.getpid()}"
        first = Instance(name)
        shown = []
        first.showRequested.connect(lambda: shown.append(True))
        try:
            self.assertTrue(self.second_start(name))
            deadline = time.time() + 3
            while not shown and time.time() < deadline:
                APP.processEvents()
            self.assertTrue(shown)
        finally:
            first.close()
        self.assertFalse(ask_running_to_show(name))


MPV = find_tool("mpv")


@unittest.skipIf(MPV is None, "mpv is not installed")
class RealMpvAcceptsTheChain(unittest.TestCase):
    def test_every_filter_runs(self):
        chain = filter_chain(True, True, EQ)
        out = subprocess.run([MPV, "--no-config", "--ao=null", "--length=0.5", "--msg-level=all=v",
                              f"--af={chain}", "av://lavfi:sine=f=440:d=2"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
                             creationflags=NO_WINDOW)
        log = out.stdout + out.stderr
        self.assertEqual(out.returncode, 0, log)
        for label in (SILENCE_LABEL, NORM_LABEL, EQ_LABEL):
            self.assertIn(f"lavfi ({label})", log)
        self.assertNotIn("Disabling filter", log)


if __name__ == "__main__":
    unittest.main()
