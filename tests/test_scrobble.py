"""Scrobbling to Last.fm / Libre.fm (run: python -m unittest discover tests)."""

import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import config, scrobble
from tests.test_recovery import SyncWorker

APP = QCoreApplication.instance() or QCoreApplication([])


class Settings(dict):
    def __getitem__(self, key):
        return self.get(key, "")


class Tracker(QObject):
    started = Signal("QVariantMap")
    finished = Signal("QVariantMap", int, float)


SONG = {"name": "Untitled", "artists": "Rex Orange County, Guest", "album": "Apricot Princess", "durationMs": 135_000}


class Rules(unittest.TestCase):
    def test_half_or_four_minutes(self):
        self.assertTrue(scrobble.should_scrobble(70_000, 135_000))
        self.assertFalse(scrobble.should_scrobble(60_000, 135_000))
        self.assertTrue(scrobble.should_scrobble(240_000, 600_000))   # 4 minutes of a long one
        self.assertFalse(scrobble.should_scrobble(25_000, 28_000))    # too short to count at all

    def test_signature_is_the_api_one(self):
        params = {"method": "auth.getToken", "api_key": "k", "format": "json"}
        self.assertEqual(scrobble.sign(params, "s"), hashlib.md5(b"api_keykmethodauth.getTokens").hexdigest())

    def test_track_params_take_the_first_artist(self):
        p = scrobble.track_params(SONG, 1000.4, 2)
        self.assertEqual(p, {"artist[2]": "Rex Orange County", "track[2]": "Untitled", "album[2]": "Apricot Princess",
                             "duration[2]": 135, "timestamp[2]": 1000})


class Scrobbling(unittest.TestCase):
    def setUp(self):
        self.settings = Settings(scrobble_service="librefm", scrobble_user="me", scrobble_session="sk")
        self.tracker = Tracker()
        tmp = Path(tempfile.mkdtemp())
        patchers = [mock.patch.object(scrobble, "QUEUE_FILE", tmp / "scrobbles.json")]
        for p in patchers:
            p.start()
            self.addCleanup(p.stop)
        self.calls = []
        self.fail = False

        def fake_call(service, method, params, session=""):
            self.calls.append((method, params))
            if self.fail:
                raise OSError("offline")
            return {}

        p = mock.patch.object(scrobble, "call", side_effect=fake_call)
        p.start()
        self.addCleanup(p.stop)
        self.s = scrobble.Scrobbler(self.tracker, self.settings, SyncWorker())

    def test_now_playing_and_a_scrobble(self):
        self.tracker.started.emit(SONG)
        self.tracker.finished.emit(SONG, 80_000, 1000.0)
        self.assertEqual([m for m, _ in self.calls], ["track.updateNowPlaying", "track.scrobble"])
        self.assertEqual(self.calls[1][1]["timestamp[0]"], 1000)
        self.assertEqual(self.s.waiting, 0)

    def test_a_skipped_song_is_not_scrobbled(self):
        self.tracker.finished.emit(SONG, 10_000, 1000.0)
        self.assertEqual(self.calls, [])

    def test_offline_scrobbles_wait_and_go_together(self):
        self.fail = True
        self.tracker.finished.emit(SONG, 80_000, 1000.0)
        self.tracker.finished.emit({**SONG, "name": "Sunflower"}, 80_000, 2000.0)
        self.assertEqual(self.s.waiting, 2)
        self.assertTrue(scrobble.QUEUE_FILE.exists())
        self.fail = False
        self.calls.clear()
        self.tracker.finished.emit({**SONG, "name": "Best Friend"}, 80_000, 3000.0)
        self.assertEqual(len(self.calls), 1)  # one request for all three
        self.assertEqual(self.calls[0][1]["track[2]"], "Best Friend")
        self.assertEqual(self.s.waiting, 0)

    def test_not_connected_sends_nothing(self):
        self.s.disconnect()
        self.tracker.started.emit(SONG)
        self.tracker.finished.emit(SONG, 80_000, 1000.0)
        self.assertEqual(self.calls, [])
        self.assertFalse(self.s.connected)


class Backups(unittest.TestCase):
    def test_the_session_key_stays_out_of_backups(self):
        with mock.patch.object(config, "read_json", return_value={"scrobble_session": "secret", "theme": "dark"}):
            settings = config.Settings()
        snap = settings.snapshot()
        self.assertNotIn("scrobble_session", snap)
        self.assertEqual(snap["theme"], "dark")


if __name__ == "__main__":
    unittest.main()
