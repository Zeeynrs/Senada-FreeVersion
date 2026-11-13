"""mpv that stops by itself is reported and started again, and Senada keeps a log
(run: python -m unittest discover tests)."""

import logging
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from PySide6.QtCore import QCoreApplication, QEventLoop, QTimer

from senada import childproc, logs
from senada.engine import AudioEngine, find_tool

APP = QCoreApplication.instance() or QCoreApplication([])


def wait(ms):
    loop = QEventLoop()
    QTimer.singleShot(ms, loop.quit)
    loop.exec()


def wait_for(cond, ms=5000):
    end = time.monotonic() + ms / 1000
    while time.monotonic() < end:
        if cond():
            return True
        wait(50)
    return cond()


class DeadProcess:
    pid = 0
    returncode = 3

    def poll(self):
        return 3


class StoppedMpv(unittest.TestCase):
    def make(self):
        with mock.patch.object(AudioEngine, "_start_mpv"), mock.patch("atexit.register"):
            e = AudioEngine()
        errors, states = [], []
        e.errorOccurred.connect(errors.append)
        e.stateChanged.connect(states.append)
        return e, errors, states

    def test_exit_before_connecting_is_reported_once(self):
        e, errors, states = self.make()
        e.proc = DeadProcess()
        e._check_mpv()
        e._check_mpv()
        wait(20)
        self.assertEqual(len(errors), 1)
        self.assertIn("3", errors[0])
        self.assertEqual(states, [False])

    def test_next_command_starts_mpv_again(self):
        e, _, _ = self.make()
        e.proc = DeadProcess()
        e._pending = [b"old\n"]
        alive = mock.Mock(**{"poll.return_value": None})
        with mock.patch.object(e, "_start_mpv", side_effect=lambda: setattr(e, "proc", alive)) as start:
            e.play("https://music.youtube.com/watch?v=x")
        start.assert_called_once()
        self.assertEqual(len(e._pending), 2)  # only the new loadfile + unpause, nothing old
        self.assertNotIn(b"old\n", e._pending)

    def test_gives_up_after_a_few_restarts(self):
        e, _, _ = self.make()
        e.proc = DeadProcess()
        with mock.patch.object(e, "_start_mpv") as start:
            for _ in range(10):
                e.resume()
        self.assertEqual(start.call_count, 3)

    def test_no_restart_while_quitting(self):
        e, _, _ = self.make()
        e.proc = DeadProcess()
        e._quitting = True
        with mock.patch.object(e, "_start_mpv") as start:
            e.resume()
        start.assert_not_called()


@unittest.skipUnless(find_tool("mpv"), "mpv is not installed")
class RealMpv(unittest.TestCase):
    def test_killed_mpv_comes_back(self):
        with mock.patch("atexit.register"):
            e = AudioEngine()
        errors = []
        e.errorOccurred.connect(errors.append)
        try:
            self.assertTrue(wait_for(lambda: e.sock.state() == e.sock.LocalSocketState.ConnectedState))
            first = e.proc
            first.kill()
            self.assertTrue(wait_for(lambda: errors), "no message after mpv was killed")
            e.resume()  # what pressing play sends
            self.assertIsNot(e.proc, first)
            self.assertTrue(wait_for(lambda: e.sock.state() == e.sock.LocalSocketState.ConnectedState))
        finally:
            e.quit()


class KillTree(unittest.TestCase):
    def test_stops_the_process(self):
        proc = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        childproc.kill_tree(proc)
        self.assertIsNotNone(proc.wait(timeout=5))
        childproc.kill_tree(proc)  # already gone: nothing happens


class LogFile(unittest.TestCase):
    def test_messages_and_missing_stderr_go_to_the_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            log_file = Path(tmp) / "senada.log"
            log = logging.getLogger("senada")
            before = list(log.handlers)
            with mock.patch.object(logs, "LOG_DIR", Path(tmp)), mock.patch.object(logs, "LOG_FILE", log_file), \
                    mock.patch.object(sys, "stderr", None):
                logs.setup()
                logging.getLogger("senada.engine").info("hello from the test")
                print("Traceback line", file=sys.stderr)
                added = [h for h in log.handlers if h not in before]
            for h in added:
                h.close()
                log.removeHandler(h)
            text = log_file.read_text(encoding="utf-8")
        self.assertIn("hello from the test", text)
        self.assertIn("Traceback line", text)


if __name__ == "__main__":
    unittest.main()
