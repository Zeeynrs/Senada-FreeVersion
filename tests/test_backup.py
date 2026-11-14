"""Backing the library up and restoring it (run: python -m unittest discover tests)."""

import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from PySide6.QtCore import QCoreApplication, QUrl

from senada import backup
from senada.store import LocalStore

APP = QCoreApplication.instance() or QCoreApplication([])


def song(n, **extra):
    return {"uri": f"yt:track:{n}", "name": f"Song {n}", "artists": "Artist", **extra}


LIBRARY = {
    "liked": [song(1, addedAt=200), song(2, addedAt=100)],
    "playlists": [{"id": "local-a", "name": "Mine", "created": 50, "tracks": [song(1)]}],
    "saved": [{"kind": "album", "id": "MPRE1", "name": "Album"}],
    "history": [song(2, playedAt=300)],
}


class FakeSettings:
    def __init__(self, data=None):
        self.data = data or {"theme": "dark"}
        self.restored = None

    def snapshot(self):
        return dict(self.data)

    def restore(self, data):
        self.restored = data


class Files(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def write(self, name, data):
        path = self.dir / name
        path.write_text(json.dumps(data) if not isinstance(data, str) else data, encoding="utf-8")
        return path

    def test_a_backup_reads_back(self):
        path = self.write("b.json", backup.make_backup(LIBRARY, {"theme": "dark"}))
        got = backup.read_backup(path)
        self.assertEqual(got["library"], LIBRARY)
        self.assertEqual(got["settings"], {"theme": "dark"})
        info = backup.summary(got)
        self.assertEqual((info["liked"], info["playlists"], info["saved"], info["history"], info["hasSettings"]),
                         (2, 1, 1, 1, True))

    def test_a_bare_library_json_counts_as_a_backup(self):
        got = backup.read_backup(self.write("library.json", LIBRARY))
        self.assertEqual(got["library"]["liked"], LIBRARY["liked"])
        self.assertIsNone(got["settings"])

    def test_other_files_are_refused(self):
        for name, content in (("x.json", {"hello": 1}), ("y.json", "not json"), ("z.json", [1, 2])):
            with self.assertRaises(backup.BackupError, msg=name):
                backup.read_backup(self.write(name, content))
        with self.assertRaises(backup.BackupError):
            backup.read_backup(self.dir / "missing.json")

    def test_a_newer_format_is_refused(self):
        data = {**backup.make_backup(LIBRARY, None), "format": backup.FORMAT + 1}
        with self.assertRaises(backup.BackupError):
            backup.read_backup(self.write("new.json", data))

    def test_copies_are_rotated(self):
        paths = []
        for i in range(4):
            paths.append(backup.keep_copy(LIBRARY, None, f"auto{i}", folder=self.dir, keep=2))
            os.utime(paths[-1], (time.time() - 100 + i, time.time() - 100 + i))  # one a "second" apart
        self.assertEqual(sorted(self.dir.glob("Senada *.json")), sorted(paths[-2:]))  # the newest two
        self.assertFalse(backup.weekly_copy_due(self.dir))
        self.assertTrue(backup.weekly_copy_due(self.dir / "empty"))


class Merge(unittest.TestCase):
    def test_nothing_is_lost_and_nothing_doubles(self):
        incoming = {
            "liked": [song(2, addedAt=100), song(3, addedAt=150)],
            "playlists": [{"id": "local-a", "name": "Renamed", "created": 50, "tracks": [song(1), song(4)]},
                          {"id": "local-b", "name": "Theirs", "created": 90, "tracks": [song(5)]}],
            "saved": [{"kind": "album", "id": "MPRE1"}, {"kind": "artist", "id": "UC1"}],
            "history": [song(2, playedAt=300), song(6, playedAt=400)],
        }
        out = backup.merge_library(LIBRARY, incoming)
        self.assertEqual([t["uri"] for t in out["liked"]], ["yt:track:1", "yt:track:3", "yt:track:2"])
        mine = next(p for p in out["playlists"] if p["id"] == "local-a")
        self.assertEqual(mine["name"], "Mine")  # not renamed
        self.assertEqual([t["uri"] for t in mine["tracks"]], ["yt:track:1", "yt:track:4"])
        self.assertEqual([p["id"] for p in out["playlists"]], ["local-b", "local-a"])  # newest first
        self.assertEqual(len(out["saved"]), 2)
        self.assertEqual([t["uri"] for t in out["history"]], ["yt:track:6", "yt:track:2"])
        self.assertEqual(LIBRARY["liked"][0]["uri"], "yt:track:1")  # the input is left alone


class Restore(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.store = LocalStore(self.dir / "library.json")
        self.store.replace({"liked": [song(9, addedAt=1)]})
        self.settings = FakeSettings()
        self.b = backup.Backup(self.store, self.settings)
        self.toasts, self.restarts = [], []
        self.b.toast.connect(self.toasts.append)
        self.b.restartRequested.connect(lambda: self.restarts.append(True))
        self.file = self.dir / "b.json"
        self.file.write_text(json.dumps(backup.make_backup(LIBRARY, {"theme": "light"})), encoding="utf-8")
        patcher = mock.patch.object(backup, "AUTO_DIR", self.dir / "backups")
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_merge_keeps_what_is_there_and_saves_a_copy_first(self):
        self.assertTrue(self.b.restore(QUrl.fromLocalFile(str(self.file)), "merge", False))
        uris = [t["uri"] for t in self.store.liked()]
        self.assertIn("yt:track:9", uris)
        self.assertIn("yt:track:1", uris)
        copies = list((self.dir / "backups").glob("Senada before restore *.json"))
        self.assertEqual(len(copies), 1)
        self.assertEqual(backup.read_backup(copies[0])["library"]["liked"][0]["uri"], "yt:track:9")
        self.assertIsNone(self.settings.restored)
        self.assertEqual(self.restarts, [])

    def test_replace_and_settings(self):
        self.assertTrue(self.b.restore(QUrl.fromLocalFile(str(self.file)), "replace", True))
        self.assertEqual([t["uri"] for t in self.store.liked()], ["yt:track:1", "yt:track:2"])
        self.assertEqual(self.settings.restored, {"theme": "light"})
        self.assertEqual(self.restarts, [True])
        # and it is on disk
        self.assertEqual(LocalStore(self.dir / "library.json").liked()[0]["uri"], "yt:track:1")

    def test_export_and_inspect(self):
        out = self.dir / "export"
        self.assertTrue(self.b.exportTo(QUrl.fromLocalFile(str(out))))
        info = self.b.inspect(QUrl.fromLocalFile(str(out.with_suffix(".json"))))
        self.assertTrue(info["ok"])
        self.assertEqual(info["liked"], 1)
        self.assertFalse(self.b.inspect(QUrl.fromLocalFile(str(self.dir / "nope.json")))["ok"])


if __name__ == "__main__":
    unittest.main()
