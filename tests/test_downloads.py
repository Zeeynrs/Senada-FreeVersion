"""Offline tests for senada.downloads (run: python -m unittest discover tests)."""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

try:
    from senada import downloads as d
except ImportError:  # PySide6 not installed
    d = None

SONG = {"uri": "yt:track:abc123", "name": "Secukupnya", "artists": "Hindia", "album": "Menari", "durationMs": 209000,
        "imageSmall": "https://example.com/s.jpg", "image": "https://example.com/m.jpg",
        "imageLarge": "https://example.com/l.jpg"}
LYRICS = {"synced": True, "lines": [{"t": 0, "text": "line"}], "source": "lrclib"}


@unittest.skipIf(d is None, "PySide6 is not installed")
class Names(unittest.TestCase):
    def test_safe_name_drops_characters_windows_forbids(self):
        self.assertEqual(d.safe_name('AC/DC: "Back" <in> Black?'), "AC_DC_ _Back_ _in_ Black_")
        self.assertEqual(d.safe_name("  ..  "), "song")

    def test_human_size(self):
        self.assertEqual(d.human_size(512), "512 B")
        self.assertEqual(d.human_size(4 * 1024 * 1024 + 300_000), "4.3 MB")


@unittest.skipIf(d is None, "PySide6 is not installed")
class Queue(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.folder, self.index = root / "Music", root / "downloads.json"
        self.dl = self.make()

    def tearDown(self):
        self.tmp.cleanup()

    def make(self):
        return d.Downloads(None, self.folder, self.index, start=False)

    def fake_download(self, dl, lyrics=LYRICS):
        """Run the next download with yt-dlp, the cover and the lyrics replaced by fakes."""
        def audio(job, video_id, base):
            path = self.folder / (base + ".m4a")
            path.write_bytes(b"x" * 2048)
            return path

        def cover(track, base):
            path = self.folder / (base + ".jpg")
            path.write_bytes(b"jpg")
            return path

        with mock.patch.object(dl, "_fetch_audio", audio), mock.patch.object(dl, "_fetch_cover", cover), \
                mock.patch.object(d.Downloads, "_fetch_lyrics", staticmethod(lambda t, v: lyrics)):
            dl.process_next()

    def test_queue_skips_duplicates_and_unknown_uris(self):
        added = self.dl.enqueue([SONG, SONG, {"uri": "senada:album:x"}, {"name": "no uri"}])
        self.assertEqual(added, 1)
        self.assertEqual(self.dl.stateOf(SONG["uri"]), d.QUEUED)
        self.assertEqual(self.dl.stateOf("yt:track:other"), d.NONE)

    def test_download_keeps_file_cover_and_lyrics(self):
        self.dl.enqueue([SONG])
        self.fake_download(self.dl)
        self.assertEqual(self.dl.stateOf(SONG["uri"]), d.DONE)
        path = Path(self.dl.path_for(SONG["uri"]))
        self.assertEqual(path.name, "Hindia - Secukupnya [abc123].m4a")
        self.assertEqual(self.dl.video_id_for(SONG["uri"]), "abc123")
        self.assertEqual(self.dl.lyrics_for(SONG["uri"]), LYRICS)
        track = self.dl.tracks()[0]
        self.assertTrue(track["imageLarge"].startswith("file:"))  # the cover shows offline
        self.assertNotIn("lyrics", track)
        page = self.dl.page()
        self.assertEqual((page["kind"], page["playUri"], len(page["tracks"])), ("offline", "senada:offline:", 1))

    def test_index_survives_a_restart_but_forgets_deleted_files(self):
        self.dl.enqueue([SONG, {**SONG, "uri": "yt:track:zzz", "name": "Other"}])
        self.fake_download(self.dl)
        self.fake_download(self.dl)
        self.assertEqual(self.make().count, 2)
        Path(self.dl.path_for("yt:track:zzz")).unlink()
        again = self.make()
        self.assertEqual([t["uri"] for t in again.tracks()], [SONG["uri"]])

    def test_remove_deletes_the_files(self):
        self.dl.enqueue([SONG])
        self.fake_download(self.dl)
        audio = Path(self.dl.path_for(SONG["uri"]))
        self.dl.remove(SONG["uri"])
        self.assertFalse(audio.exists())
        self.assertEqual(list(self.folder.iterdir()), [])
        self.assertEqual(self.dl.stateOf(SONG["uri"]), d.NONE)

    def test_remove_cancels_a_waiting_download(self):
        self.dl.enqueue([SONG])
        self.dl.remove(SONG["uri"])
        self.assertEqual(self.dl.pending, 0)
        self.dl.process_next()  # nothing left to do
        self.assertEqual(self.dl.count, 0)

    def test_failed_download_leaves_nothing_behind(self):
        self.dl.enqueue([SONG])

        def broken(job, video_id, base):
            (self.folder / (base + ".m4a.part")).write_bytes(b"half")
            raise d.DownloadError("ERROR: video unavailable")

        failures = []
        self.dl._event.connect(lambda e: failures.append(e) if e[0] == "failed" else None)
        with mock.patch.object(self.dl, "_fetch_audio", broken):
            self.dl.process_next()
        self.assertEqual(self.dl.count, 0)
        self.assertEqual(list(self.folder.iterdir()), [])
        self.assertIn("video unavailable", failures[0][2])

    def test_imported_song_downloads_its_match(self):
        resolver = mock.Mock()
        resolver.match.return_value = {"v": "matched1"}
        dl = d.Downloads(resolver, self.folder, self.index, start=False)
        dl.enqueue([{**SONG, "uri": "spotify:track:sp1"}])
        self.fake_download(dl, lyrics=None)
        self.assertEqual(dl.video_id_for("spotify:track:sp1"), "matched1")
        self.assertIsNone(dl.lyrics_for("spotify:track:sp1"))


if __name__ == "__main__":
    unittest.main()
