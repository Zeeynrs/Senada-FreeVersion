"""Offline tests for senada.effects (run: python -m unittest discover tests)."""

import unittest

try:
    from senada import effects as fx
except ImportError:  # PySide6 not installed
    fx = None


class FakeSettings(dict):
    def __getitem__(self, key):
        return self.get(key)


@unittest.skipIf(fx is None, "PySide6 is not installed")
class Effects(unittest.TestCase):
    def setUp(self):
        self.settings = FakeSettings()
        self.fx = fx.AudioEffects(self.settings)

    def test_moving_a_band_makes_the_preset_custom_and_clamps(self):
        self.fx.usePreset("Rock")
        self.fx.setBand(0, 3.0)
        self.assertEqual(self.fx.preset, "Custom")
        self.assertEqual(self.fx.bands[0], 1.0)

    def test_presets_cycle(self):
        names = self.fx.presetNames
        self.fx.usePreset(names[-1])
        self.fx.nextPreset()
        self.assertEqual(self.fx.preset, names[0])
        self.assertEqual(self.fx.bands, fx.PRESETS[names[0]])

    def test_tempo_is_kept_in_range(self):
        self.fx.setTempo(5)
        self.assertEqual(self.fx.tempo, fx.TEMPO_MAX)
        self.fx.setTempo(0.1)
        self.assertEqual(self.fx.tempo, fx.TEMPO_MIN)

    def test_saved_values_come_back(self):
        self.fx.setKeepPitch(True)
        self.fx.setBand(2, -0.5)
        self.fx._save()  # normally a moment after the last change
        again = fx.AudioEffects(self.settings)
        self.assertTrue(again.keepPitch)
        self.assertEqual(again.bands[2], -0.5)

    def test_broken_saved_bands_fall_back_to_the_default(self):
        self.settings["effects"] = {"bands": [1, 2]}
        self.assertEqual(fx.AudioEffects(self.settings).bands, fx.DEFAULTS["bands"])


if __name__ == "__main__":
    unittest.main()
