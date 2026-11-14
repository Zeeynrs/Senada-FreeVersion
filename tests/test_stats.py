"""What was listened to (plays.py) and the listening statistics (stats.py)
(run: python -m unittest discover tests)."""

import datetime
import tempfile
import unittest
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import stats
from senada.plays import PlayTracker

APP = QCoreApplication.instance() or QCoreApplication([])


class FakePlayer(QObject):
    trackChanged = Signal()
    positionChanged = Signal()
    stateChanged = Signal()

    def __init__(self):
        super().__init__()
        self.state, self.position = {}, 0
        self.played = None

    def start(self, n, duration=200_000):
        self.state = {"hasTrack": True, "isPlaying": True, "uri": f"yt:track:{n}", "name": f"Song {n}",
                      "artists": f"Artist {n % 2}, Guest", "durationMs": duration}
        self.position = 0
        self.trackChanged.emit()

    def move(self, *positions):
        for p in positions:
            self.position = p
            self.positionChanged.emit()

    def cache_tracks(self, tracks):
        pass

    def playUris(self, uris, index):
        self.played = (uris, index)


class Tracker(unittest.TestCase):
    def setUp(self):
        self.player = FakePlayer()
        self.tracker = PlayTracker(self.player)
        self.done = []
        self.tracker.finished.connect(lambda t, ms, at: self.done.append((t["uri"], ms)))

    def test_only_time_played_counts(self):
        self.player.start(1)
        self.player.move(1000, 2000, 60_000, 61_000)   # a seek to 60 s in the middle
        self.player.state["isPlaying"] = False
        self.player.move(62_000)                        # paused: not listening
        self.player.start(2)
        self.assertEqual(self.done, [("yt:track:1", 3000)])

    def test_quitting_reports_the_song_playing(self):
        self.player.start(1)
        self.player.move(1500)
        self.tracker.flush()
        self.tracker.flush()  # only once
        self.assertEqual(self.done, [("yt:track:1", 1500)])


class Log(unittest.TestCase):
    def setUp(self):
        self.log = stats.PlayLog(Path(tempfile.mkdtemp()) / "plays.db")
        self.addCleanup(self.log.close)
        now = datetime.datetime.now().timestamp()
        for n, plays in ((1, 3), (2, 1), (3, 2)):
            for i in range(plays):
                self.log.add({"uri": f"yt:track:{n}", "name": f"Song {n}", "artists": f"Artist {n % 2}, Guest",
                              "durationMs": 200_000}, 120_000, now - i * 60)
        self.log.add({"uri": "yt:track:9", "name": "Old", "artists": "Gone"}, 60_000, now - 400 * 86400)

    def test_summary_of_a_period(self):
        s = self.log.summary(stats.period_start("month"), "day")
        self.assertEqual((s["plays"], s["minutes"], s["songs"], s["artists"]), (6, 12, 3, 2))
        self.assertEqual([t["uri"] for t in s["topSongs"]], ["yt:track:1", "yt:track:3", "yt:track:2"])
        self.assertEqual(s["topSongs"][0]["plays"], 3)
        self.assertEqual([a["name"] for a in s["topArtists"]], ["Artist 1", "Artist 0"])  # first artist only
        self.assertEqual(sum(s["per"].values()), 12)

    def test_all_time_has_the_old_play(self):
        s = self.log.summary(stats.period_start("all"), "month")
        self.assertEqual(s["plays"], 7)
        self.assertGreater(self.log.first_play(), 0)


class Rules(unittest.TestCase):
    def test_what_counts_as_a_play(self):
        self.assertTrue(stats.counts_as_play(30_000, 200_000))
        self.assertFalse(stats.counts_as_play(29_000, 200_000))
        self.assertTrue(stats.counts_as_play(20_000, 35_000))   # half of a short song
        self.assertFalse(stats.counts_as_play(5_000, 0))

    def test_bars_cover_the_period(self):
        now = datetime.datetime(2026, 11, 14, 12)
        week = stats.bars({"2026-11-14": 30}, "week", now)
        self.assertEqual(len(week), 7)
        self.assertEqual(week[-1], {"key": "2026-11-14", "label": "14", "minutes": 30})
        year = stats.bars({"2026-03": 90}, "year", now)
        self.assertEqual([b["key"] for b in year][:3], ["2026-01", "2026-02", "2026-03"])
        self.assertEqual(len(year), 11)
        self.assertEqual(year[2]["minutes"], 90)
        self.assertGreaterEqual(len(stats.bars({}, "all", now)), 12)


class Recording(unittest.TestCase):
    def test_short_listens_are_not_recorded_and_plays_are(self):
        player = FakePlayer()
        tracker = PlayTracker(player)
        log = stats.PlayLog(Path(tempfile.mkdtemp()) / "plays.db")
        self.addCleanup(log.close)
        s = stats.Stats(tracker, player, log)
        player.start(1)
        player.move(*range(0, 10_001, 1000))        # 10 s: skipped
        player.start(2)
        player.move(*range(0, 45_001, 1000))        # 45 s: a play
        tracker.flush()
        data = s.summary("week")
        self.assertEqual(data["plays"], 1)
        self.assertEqual(data["topSongs"][0]["uri"], "yt:track:2")
        self.assertEqual(len(data["bars"]), 7)
        s.play(data["topSongs"], 0)
        self.assertEqual(player.played, (["yt:track:2"], 0))


if __name__ == "__main__":
    unittest.main()
