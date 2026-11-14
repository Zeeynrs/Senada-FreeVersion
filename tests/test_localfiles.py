"""Music files on this computer (run: python -m unittest discover tests)."""

import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from PySide6.QtCore import QCoreApplication, QUrl

from senada import localfiles
from senada.player import Player
from tests.test_recovery import FakeEngine, FakeResolver, FakeStore, FakeStreams, SyncWorker

APP = QCoreApplication.instance() or QCoreApplication([])


class Settings(dict):
    def __getitem__(self, key):
        return self.get(key)


def make_music(root: Path) -> Path:
    (root / "Album").mkdir(parents=True)
    for name in ("01 - Rex Orange County - Untitled.mp3", "Sunflower.flac", "cover.jpg", "notes.txt"):
        (root / "Album" / name).write_bytes(b"not really audio")
    (root / "Album" / "Sunflower.lrc").write_text("[00:01.00]I'm in love\n[00:03.50]with you\n", encoding="utf-8")
    return root


class Scanning(unittest.TestCase):
    def setUp(self):
        self.root = make_music(Path(tempfile.mkdtemp()))

    def test_audio_files_become_tracks_named_from_the_file(self):
        found = localfiles.scan([str(self.root)], {})
        tracks = sorted((e["track"] for e in found.values()), key=lambda t: t["name"])
        self.assertEqual([t["name"] for t in tracks], ["Sunflower", "Untitled"])
        untitled = tracks[1]
        self.assertEqual(untitled["artists"], "Rex Orange County")
        self.assertEqual(untitled["album"], "Album")
        self.assertTrue(untitled["uri"].startswith(localfiles.PREFIX))
        self.assertEqual(tracks[0]["artists"], "Unknown artist")

    def test_unchanged_files_are_not_read_again(self):
        first = localfiles.scan([str(self.root)], {})
        with mock.patch.object(localfiles, "read_track", side_effect=AssertionError("read again")):
            again = localfiles.scan([str(self.root)], first)
        self.assertEqual(again, first)
        path = next(p for p in first if p.endswith(".flac"))
        os.utime(path, (time.time() + 5, time.time() + 5))
        with mock.patch.object(localfiles, "read_track", return_value={"uri": "x"}) as read:
            localfiles.scan([str(self.root)], first)
        read.assert_called_once()


class Library(unittest.TestCase):
    def setUp(self):
        self.root = make_music(Path(tempfile.mkdtemp()))
        tmp = Path(tempfile.mkdtemp())
        p = mock.patch.object(localfiles, "INDEX_FILE", tmp / "localfiles.json")
        p.start()
        self.addCleanup(p.stop)
        self.files = localfiles.LocalFiles(Settings(local_folders=[]))

    def scan_now(self):
        self.files._on_scanned(localfiles.scan([str(self.root)], {}))

    def test_folders_page_and_lyrics(self):
        with mock.patch.object(self.files, "rescan"):
            self.files.addFolder(QUrl.fromLocalFile(str(self.root)))
            self.files.addFolder(QUrl.fromLocalFile(str(self.root)))  # once only
        self.assertEqual(self.files.folders, [os.path.normpath(str(self.root))])
        self.scan_now()
        page = self.files.page()
        self.assertEqual(len(page["tracks"]), 2)
        self.assertEqual(page["playUri"], "senada:local:")
        flac = next(t for t in page["tracks"] if t["name"] == "Sunflower")
        self.assertTrue(self.files.path_for(flac["uri"]))
        lyrics = self.files.lyrics_for(flac["uri"])
        self.assertTrue(lyrics["synced"])
        self.assertEqual([l["t"] for l in lyrics["lines"]], [1000, 3500])
        self.assertIsNone(self.files.path_for("local:file:/nowhere/x.mp3"))

    def test_without_folders_the_page_says_how(self):
        self.assertIn("Settings", self.files.page()["note"])


class Playing(unittest.TestCase):
    def test_a_music_file_plays_from_disk_and_a_broken_one_is_skipped(self):
        root = make_music(Path(tempfile.mkdtemp()))
        tracks = sorted((e["track"] for e in localfiles.scan([str(root)], {}).values()), key=lambda t: t["name"])
        engine = FakeEngine()
        player = Player(SyncWorker(), engine, FakeResolver({}), {}, FakeStore(), None)
        player.streams = FakeStreams({})
        player.localfiles = localfiles.LocalFiles(Settings(local_folders=[]))
        player._queue = list(tracks)
        player._play_index(0)
        self.assertEqual(engine.played, [localfiles.path_of(tracks[0]["uri"])])
        engine.loadFailed.emit()   # mpv could not open it: on to the next song
        self.assertEqual(engine.played[-1], localfiles.path_of(tracks[1]["uri"]))


if __name__ == "__main__":
    unittest.main()
