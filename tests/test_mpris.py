"""MPRIS track ids are valid D-Bus object paths (run: python -m unittest discover tests)."""

import re
import unittest

try:
    from senada.mpris import track_object_path
except ImportError:  # no dbus-python (Windows)
    track_object_path = None


@unittest.skipIf(track_object_path is None, "dbus-python is not installed")
class TrackPath(unittest.TestCase):
    def test_youtube_ids_with_dashes_make_valid_paths(self):
        for vid in ("h8DeZSB2o-c", "a_b", "", "x-y_z"):
            self.assertRegex(track_object_path(vid), r"^/org/senada/track/[A-Za-z0-9_]+$")

    def test_different_ids_stay_different(self):
        self.assertNotEqual(track_object_path("a-b"), track_object_path("a_b"))


if __name__ == "__main__":
    unittest.main()
