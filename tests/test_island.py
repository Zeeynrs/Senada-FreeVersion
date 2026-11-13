"""The Hyprland rules for the mini player match its window (run: python -m unittest discover tests)."""

import re
import unittest
from pathlib import Path

from senada import island

QML = (Path(__file__).resolve().parent.parent / "qml" / "MiniPlayer.qml").read_text()


def qml_int(name):
    return int(re.search(rf"property int {name}: (\d+)", QML).group(1))


class Rules(unittest.TestCase):
    def test_title_and_size_match_the_window(self):
        self.assertIn(f'title: "{island.TITLE}"', QML)
        margin = qml_int("margin")
        self.assertEqual(island.SIZE, (qml_int("wideW") + 2 * margin, qml_int("wideH") + 2 * margin))

    def test_not_owned_by_the_main_window(self):
        # an owned window is hidden by Windows while the main window is minimized
        self.assertIn("transientParent: null", QML)

    def test_centred_between_the_bars(self):
        rule = island.lua_rule((34, 40, 0, 0))
        self.assertIn('move = {"(34+(monitor_w-34)*0.5-window_w*0.5)", "(40)"}', rule)
        self.assertIn("pin = true", rule)
        self.assertIn("move (0+(monitor_w-0)*0.5-window_w*0.5) (0), title:^(Senada mini player)$",
                      island.legacy_rules())


if __name__ == "__main__":
    unittest.main()
