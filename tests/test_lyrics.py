"""Offline tests for senada.lyrics (run: python -m unittest discover tests)."""

import unittest
from unittest import mock

try:
    from senada import lyrics
except ImportError:  # PySide6 not installed
    lyrics = None

SYNCED = {"synced": True, "lines": [{"t": 0, "text": "synced"}]}
PLAIN = {"synced": False, "lines": [{"t": 0, "text": "plain"}]}


@unittest.skipIf(lyrics is None, "PySide6 is not installed")
class AutoSource(unittest.TestCase):
    def run_auto(self, **results):
        def fetcher(name):
            def fetch(track):
                value = results.get(name)
                if isinstance(value, Exception):
                    raise value
                return value
            return fetch
        fakes = {name: fetcher(name) for name in lyrics.AUTO_ORDER}
        with mock.patch.dict(lyrics.FETCHERS, fakes):
            return lyrics.fetch_lyrics({"name": "x", "artists": "y"}, "auto")

    def test_first_synced_wins(self):
        self.assertEqual(self.run_auto(lrclib=SYNCED, netease=SYNCED)["source"], "lrclib")

    def test_synced_beats_earlier_plain(self):
        found = self.run_auto(lrclib=PLAIN, ytmusic=None, netease=SYNCED)
        self.assertEqual((found["source"], found["synced"]), ("netease", True))

    def test_plain_when_nothing_is_synced(self):
        found = self.run_auto(lrclib=None, ytmusic=PLAIN, netease=None)
        self.assertEqual((found["source"], found["synced"]), ("ytmusic", False))

    def test_a_failing_source_is_skipped(self):
        self.assertEqual(self.run_auto(lrclib=OSError("down"), ytmusic=SYNCED)["source"], "ytmusic")

    def test_error_only_when_every_source_failed_or_was_empty(self):
        with self.assertRaises(OSError):
            self.run_auto(lrclib=OSError("down"))
        self.assertEqual(self.run_auto()["lines"], [])

    def test_single_source_reports_nothing_found(self):
        with mock.patch.dict(lyrics.FETCHERS, {"netease": lambda t: None}):
            found = lyrics.fetch_lyrics({}, "netease")
        self.assertEqual((found["lines"], found["source"]), ([], "netease"))


@unittest.skipIf(lyrics is None, "PySide6 is not installed")
class Parsing(unittest.TestCase):
    def test_parse_lrc_sorts_and_repeats_stamps(self):
        lines = lyrics.parse_lrc("[00:05.00][00:01.50]chorus\n[00:03.00]verse")
        self.assertEqual([(l["t"], l["text"]) for l in lines], [(1500, "chorus"), (3000, "verse"), (5000, "chorus")])

    def test_netease_credit_lines_are_recognised(self):
        self.assertTrue(lyrics.CREDIT_RE.match("作词 : Baskara Putra"))
        self.assertTrue(lyrics.CREDIT_RE.match("制作人 : Chris Martin"))
        self.assertFalse(lyrics.CREDIT_RE.match("Look at the stars"))
        self.assertFalse(lyrics.CREDIT_RE.match("無敵の笑顔で荒らすメディア"))


if __name__ == "__main__":
    unittest.main()
