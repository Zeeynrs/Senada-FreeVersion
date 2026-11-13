"""The equalizer and tempo reach mpv (run: python -m unittest discover tests)."""

import subprocess
import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication

from senada import effects as fx
from senada.config import NO_WINDOW
from senada.engine import EQ_LABEL, AudioEngine, eq_commands, eq_graph, find_tool

APP = QCoreApplication.instance() or QCoreApplication([])


class FakeSettings(dict):
    def __getitem__(self, key):
        return self.get(key)


def engine():
    with mock.patch.object(AudioEngine, "_start_mpv"), mock.patch("atexit.register"):
        e = AudioEngine()
    sent = []
    e._send_command = sent.append
    return e, sent


class EngineEqualizer(unittest.TestCase):
    GAINS = [7.8, 5.4, 1.2, -0.6, 0, 0.6]

    def test_first_gains_build_the_filter(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        self.assertEqual(sent, [["af", "set", f"@{EQ_LABEL}:lavfi=[{eq_graph(self.GAINS)}]"]])

    def test_later_gains_change_the_running_filter(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        sent.clear()
        e.set_equalizer([1, 2, 3, 4, 5, 6])
        self.assertTrue(sent and all(c[0] == "af-command" and c[1] == EQ_LABEL for c in sent))
        self.assertIn(["af-command", EQ_LABEL, "g", "6", "treble@b5"], sent)
        self.assertIn(["af-command", EQ_LABEL, "volume", "-3dB", "volume@pre"], sent)

    def test_the_same_gains_send_nothing(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        sent.clear()
        e.set_equalizer(list(self.GAINS))
        self.assertEqual(sent, [])

    def test_off_takes_the_filter_out(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        e.set_equalizer(None)
        self.assertEqual(sent[-1], ["af", "clr", ""])

    def test_changed_gains_are_built_in_at_the_next_song(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        e.set_equalizer([1, 2, 3, 4, 5, 6])
        sent.clear()
        e.play("https://example.com/song.m4a")
        self.assertEqual(sent[0], ["af", "set", f"@{EQ_LABEL}:lavfi=[{eq_graph([1, 2, 3, 4, 5, 6])}]"])

    def test_a_new_mpv_gets_the_effects_again(self):
        e, sent = engine()
        e.set_equalizer(self.GAINS)
        e.set_tempo(1.25, False)
        sent.clear()
        e._on_connected()
        self.assertIn(["set_property", "speed", 1.25], sent)
        self.assertIn(["set_property", "audio-pitch-correction", False], sent)
        self.assertIn(["af", "set", f"@{EQ_LABEL}:lavfi=[{eq_graph(self.GAINS)}]"], sent)

    def test_boosts_leave_headroom(self):
        self.assertTrue(eq_graph([6, 0, 0, 0, 0, 0]).startswith("volume@pre=volume=-3dB,"))
        self.assertTrue(eq_graph([-6, 0, 0, 0, 0, 0]).startswith("volume@pre=volume=0dB,"))
        self.assertEqual(len(eq_commands(self.GAINS)), 1 + len(fx.BANDS))


class EffectsDriveTheEngine(unittest.TestCase):
    def setUp(self):
        self.engine = mock.Mock()
        self.fx = fx.AudioEffects(FakeSettings(), self.engine)

    def test_flat_by_default_means_no_filter(self):
        self.engine.set_equalizer.assert_called_with(None)
        self.engine.set_tempo.assert_called_with(1.0, False)

    def test_a_preset_sends_its_gains_in_db(self):
        self.fx.usePreset("Bass Boost")
        self.engine.set_equalizer.assert_called_with([round(g * fx.MAX_DB, 2) for g in fx.PRESETS["Bass Boost"]])

    def test_switching_off_takes_the_equalizer_out(self):
        self.fx.usePreset("Rock")
        self.fx.setEnabled(False)
        self.engine.set_equalizer.assert_called_with(None)

    def test_tempo_and_pitch(self):
        self.fx.setTempo(1.5)
        self.fx.setKeepPitch(True)
        self.engine.set_tempo.assert_called_with(1.5, True)


MPV = find_tool("mpv")


@unittest.skipIf(MPV is None, "mpv is not installed")
class RealMpvAcceptsTheGraph(unittest.TestCase):
    def test_graph_runs(self):
        graph = eq_graph([g * fx.MAX_DB for g in fx.PRESETS["Rock"]])
        out = subprocess.run([MPV, "--no-config", "--ao=null", "--length=0.5", "--msg-level=all=v",
                              f"--af=@{EQ_LABEL}:lavfi=[{graph}]", "av://lavfi:sine=f=440:d=2"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30, creationflags=NO_WINDOW)
        log = out.stdout + out.stderr
        self.assertEqual(out.returncode, 0, log)
        self.assertIn(f"lavfi ({EQ_LABEL})", log)
        self.assertNotIn("Disabling filter", log)


if __name__ == "__main__":
    unittest.main()
