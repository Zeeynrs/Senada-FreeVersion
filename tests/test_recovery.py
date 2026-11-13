"""Offline tests for what happens when a song will not play: another upload is tried, the queue
moves on, and YouTube's temporary block stops playback instead of skipping through everything.
(run: python -m unittest discover tests)"""

import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import matching, resolver as resolver_mod
from senada.player import MAX_FAIL_STREAK, Player
from senada.resolver import AudioResolver
from senada.streams import StreamError, is_blocked, watch_url

APP = QCoreApplication.instance() or QCoreApplication([])

BLOCKED = "ERROR: [youtube] abc: Sign in to confirm you’re not a bot. Use --cookies-from-browser"
GONE = "ERROR: [youtube] abc: Video unavailable"


def cand(vid, score):
    return {"id": vid, "name": "Song", "artists": "Artist", "match": {"score": score}}


class Blocked(unittest.TestCase):
    def test_recognises_youtube_limits(self):
        self.assertTrue(is_blocked(BLOCKED))
        self.assertTrue(is_blocked("ERROR: unable to download webpage: HTTP Error 429: Too Many Requests"))
        self.assertFalse(is_blocked(GONE))
        self.assertFalse(is_blocked(""))


class Alternative(unittest.TestCase):
    def setUp(self):
        with mock.patch.object(resolver_mod, "read_json", return_value={}):
            self.r = AudioResolver()
        self.r._save_cache = lambda: None

    def test_skips_the_failed_upload_and_remembers_the_one_that_plays(self):
        track = {"uri": "spotify:track:1", "name": "Song", "artists": "Artist"}
        self.r.candidates = lambda meta, thorough=False: [cand("bad", 100), cand("dead", 95), cand("good", 90)]

        def stream_for(vid):
            if vid == "dead":
                raise StreamError(GONE)
            return "https://audio/" + vid

        info, url = self.r.alternative(track, {"bad"}, stream_for)
        self.assertEqual((info["v"], url), ("good", "https://audio/good"))
        self.assertEqual(self.r.cached("spotify:track:1")["v"], "good")

    def test_catalog_song_takes_only_a_sure_match_and_never_itself(self):
        track = {"uri": "yt:track:orig", "name": "Song", "artists": "Artist"}
        self.r.candidates = lambda meta, thorough=False: [cand("orig", 100), cand("meh", matching.ACCEPT - 1)]
        self.assertIsNone(self.r.alternative(track, set(), lambda vid: "https://audio/" + vid))

    def test_catalog_song_plays_its_replacement_next_time(self):
        track = {"uri": "yt:track:orig", "name": "Song", "artists": "Artist"}
        self.r.candidates = lambda meta, thorough=False: [cand("other", 98)]
        self.r.alternative(track, set(), lambda vid: "https://audio/" + vid)
        self.assertEqual(self.r.match(track)["v"], "other")

    def test_block_is_not_hidden(self):
        track = {"uri": "spotify:track:1", "name": "Song", "artists": "Artist"}
        self.r.candidates = lambda meta, thorough=False: [cand("x", 100)]

        def stream_for(vid):
            raise StreamError(BLOCKED)

        with self.assertRaises(StreamError):
            self.r.alternative(track, set(), stream_for)


# ---- the player with everything around it faked -------------------------------------------

class FakeEngine(QObject):
    positionChanged = Signal(int)
    durationChanged = Signal(int)
    stateChanged = Signal(bool)
    trackEnded = Signal()
    loadFailed = Signal()
    errorOccurred = Signal(str)

    def __init__(self):
        super().__init__()
        self.played, self.stopped = [], 0

    def play(self, url):
        self.played.append(url)

    def stop(self):
        self.stopped += 1

    def set_volume(self, v):
        pass

    def queue_next(self, url):
        pass


class SyncWorker(QObject):
    error = Signal(str)

    def run(self, fn, on_ok=None, on_err=None):
        try:
            result = fn()
        except Exception as e:  # noqa: BLE001 - mirrors worker.Async
            if on_err:
                on_err(e)
        else:
            if on_ok:
                on_ok(result)


class FakeStore:
    def is_liked(self, uri):
        return False

    def add_history(self, track):
        pass


class FakeResolver:
    def __init__(self, matches, alternatives=None):
        self.matches, self.alternatives, self.alt_calls = matches, alternatives or {}, []

    def match(self, track):
        return self.matches.get(track["uri"])

    def cached(self, uri):
        return None

    def alternative(self, track, exclude, stream_for):
        self.alt_calls.append((track["uri"], set(exclude)))
        alt = self.alternatives.get(track["uri"])
        if isinstance(alt, Exception):
            raise alt
        return alt


class FakeStreams:
    def __init__(self, urls):
        self.urls = urls  # video id -> url, or an exception to raise

    def resolve(self, vid):
        found = self.urls.get(vid, StreamError("yt-dlp found no audio stream"))
        if isinstance(found, Exception):
            raise found
        return found

    def forget(self, vid):
        pass

    def cached(self, vid):
        return None


def song(n):
    return {"uri": f"spotify:track:{n}", "name": f"Song {n}", "artists": "Artist"}


class Recovery(unittest.TestCase):
    def make(self, matches, urls, alternatives=None):
        self.engine, self.worker = FakeEngine(), SyncWorker()
        self.errors, self.matched = [], []
        self.worker.error.connect(self.errors.append)
        self.resolver = FakeResolver(matches, alternatives)
        p = Player(self.worker, self.engine, self.resolver, {}, FakeStore(), None)
        p.streams = FakeStreams(urls)
        p.trackMatched.connect(lambda uri, patch: self.matched.append((uri, dict(patch))))
        self.player = p
        return p

    def start(self, tracks):
        self.player._queue = list(tracks)
        self.player._play_index(0)

    def test_gone_upload_is_replaced_by_another(self):
        self.make({"spotify:track:1": {"v": "gone", "s": 100}}, {"gone": StreamError(GONE)},
                  {"spotify:track:1": ({"v": "alt", "s": 90}, "https://audio/alt")})
        self.start([song(1), song(2)])
        self.assertEqual(self.engine.played, ["https://audio/alt"])
        self.assertEqual(self.player._queue_index, 0)

    def test_block_stops_instead_of_skipping(self):
        self.make({"spotify:track:1": {"v": "a", "s": 100}}, {"a": StreamError(BLOCKED)})
        self.start([song(1), song(2)])
        self.assertEqual(self.engine.played, [])
        self.assertEqual(self.player._queue_index, 0)
        self.assertTrue(self.engine.stopped)
        self.assertIn("limiting", self.errors[-1])

    def test_not_found_moves_on_and_marks_the_song(self):
        self.make({"spotify:track:2": {"v": "b", "s": 100}}, {"b": "https://audio/b"})
        self.start([song(1), song(2)])
        self.assertEqual(self.engine.played, ["https://audio/b"])
        self.assertIn(("spotify:track:1", {"matchScore": 0}), self.matched)

    def test_many_failures_in_a_row_stop_playback(self):
        self.make({}, {})
        self.start([song(n) for n in range(1, 8)])
        self.assertEqual(self.player._queue_index, MAX_FAIL_STREAK - 1)
        self.assertIn("Several songs", self.errors[-1])

    def test_stream_breaking_in_mpv_tries_mpv_then_another_upload_then_moves_on(self):
        self.make({"spotify:track:1": {"v": "a", "s": 100}, "spotify:track:2": {"v": "b", "s": 100}},
                  {"a": "https://audio/a", "b": "https://audio/b"},
                  {"spotify:track:1": ({"v": "alt", "s": 90}, "https://audio/alt")})
        self.start([song(1), song(2)])
        self.engine.loadFailed.emit()  # direct address broke: mpv's own lookup
        self.assertEqual(self.engine.played[-1], watch_url("a"))
        self.engine.loadFailed.emit()  # that too: another upload
        self.assertEqual(self.engine.played[-1], "https://audio/alt")
        self.engine.loadFailed.emit()  # and that too: next song
        self.assertEqual(self.engine.played[-1], "https://audio/b")
        self.assertEqual(self.player._queue_index, 1)

    def test_a_song_that_plays_resets_the_count(self):
        self.make({}, {})
        self.start([song(1), song(2)])
        self.engine.stateChanged.emit(True)
        self.assertEqual(self.player._fail_streak, 0)


if __name__ == "__main__":
    unittest.main()
