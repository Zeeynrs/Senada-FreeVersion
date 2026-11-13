"""Fewer position updates while Senada is out of sight, and mpv never outlives Senada
(run: python -m unittest discover tests)."""

import os
import signal
import subprocess
import sys
import textwrap
import time
import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication

from senada.engine import AudioEngine
from senada.player import BACKGROUND_POSITION_MS

APP = QCoreApplication.instance() or QCoreApplication([])
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def engine():
    with mock.patch.object(AudioEngine, "_start_mpv"), mock.patch("atexit.register"):
        e = AudioEngine()
    seen = []
    e.positionChanged.connect(seen.append)
    return e, seen


def tick(e, ms):
    e._handle_message({"event": "property-change", "name": "time-pos", "data": ms / 1000})


class PositionSteps(unittest.TestCase):
    def test_every_update_while_in_view(self):
        e, seen = engine()
        for ms in range(0, 1000, 62):
            tick(e, ms)
        self.assertEqual(len(seen), 17)

    def test_a_few_per_second_out_of_view(self):
        e, seen = engine()
        e.set_position_step(BACKGROUND_POSITION_MS)
        for ms in range(0, 2000, 62):  # mpv's ~16 updates a second
            tick(e, ms)
        self.assertLessEqual(len(seen), 2000 // BACKGROUND_POSITION_MS + 1)
        self.assertGreaterEqual(len(seen), 6)

    def test_seeks_and_new_tracks_still_come_through_at_once(self):
        e, seen = engine()
        e.set_position_step(BACKGROUND_POSITION_MS)
        tick(e, 60_000)
        tick(e, 60_050)
        tick(e, 0)  # next track
        tick(e, 120_000)  # seek
        self.assertEqual(seen, [60_000, 0, 120_000])

    def test_back_in_view_catches_up(self):
        e, seen = engine()
        e.set_position_step(BACKGROUND_POSITION_MS)
        tick(e, 1000)
        tick(e, 1100)
        e.set_position_step(0)
        self.assertEqual(seen[-1], 1100)


@unittest.skipUnless(sys.platform.startswith("linux"), "PR_SET_PDEATHSIG is Linux only")
class ChildEndsWithParent(unittest.TestCase):
    def test_child_dies_when_parent_is_killed(self):
        # a stand-in for Senada starts a long-running child the way Senada starts mpv, then is killed
        parent = subprocess.Popen([sys.executable, "-c", textwrap.dedent(f"""
            import sys, time; sys.path.insert(0, {ROOT!r})
            from senada.childproc import popen_tied
            proc, _ = popen_tied(["sleep", "60"])
            print(proc.pid, flush=True)
            time.sleep(60)
        """)], stdout=subprocess.PIPE, text=True)
        child = int(parent.stdout.readline())
        parent.send_signal(signal.SIGKILL)
        parent.wait()
        for _ in range(50):
            try:
                os.kill(child, 0)
            except ProcessLookupError:
                return
            time.sleep(0.05)
        os.kill(child, signal.SIGKILL)
        self.fail("the child kept running after its parent was killed")


if __name__ == "__main__":
    unittest.main()
