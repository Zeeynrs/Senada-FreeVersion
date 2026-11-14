"""Opening the artist of a song that has no YouTube Music artist id (run: python -m unittest discover tests)."""

import unittest
from unittest import mock

try:
    from PySide6.QtCore import QCoreApplication
    from senada import library as lib, ytmusic
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:  # PySide6 not installed
    lib = None


def card(name, cid):
    return {"kind": "artist", "id": cid, "name": name}


class SyncWorker:
    def run(self, fn, ok, fail):
        try:
            result = fn()
        except Exception as e:  # noqa: BLE001
            fail(e)
        else:
            ok(result)


@unittest.skipIf(lib is None, "PySide6 is not installed")
class FindArtist(unittest.TestCase):
    def setUp(self):
        store = mock.Mock()
        store.playlists.return_value = []
        store.saved.return_value = []
        store.history.return_value = []
        self.lib = lib.Library(store, mock.Mock(), SyncWorker(), mock.Mock())
        self.found, self.toasts = [], []
        self.lib.artistFound.connect(self.found.append)
        self.lib.toast.connect(self.toasts.append)

    def test_the_first_artist_of_the_list_wins(self):
        cards = [card("Kali Uchis", "UCk"), card("Tyler, The Creator", "UCt"), card("Tyler", "UCx")]
        self.assertEqual(lib.best_artist("Tyler, The Creator, Kali Uchis", cards)["id"], "UCt")  # comma in the name
        cards = [card("The Emotions", "UCe"), card("Earth, Wind & Fire", "UCw")]
        self.assertEqual(lib.best_artist("Earth, Wind & Fire, The Emotions", cards)["id"], "UCw")
        self.assertEqual(lib.best_artist("Tulus", [card("Tulus Dwi", "UC1"), card("TULUS", "UC2")])["id"], "UC2")
        self.assertEqual(lib.best_artist("Beyoncé", [card("Someone", "UC3"), card("Beyonce", "UC4")])["id"], "UC4")

    def test_otherwise_the_first_card(self):
        self.assertEqual(lib.best_artist("Unknown", [card("Other", "UC5")])["id"], "UC5")
        self.assertIsNone(lib.best_artist("Unknown", []))

    def test_found_once_then_remembered(self):
        search = mock.Mock(return_value=[card("Post Malone", "UCpm")])
        with mock.patch.object(ytmusic, "search_artists", search):
            self.lib.findArtist("Post Malone, Swae Lee")
            self.lib.findArtist("post malone, swae lee")
        self.assertEqual(self.found, ["UCpm", "UCpm"])
        search.assert_called_once()

    def test_not_found_says_so(self):
        with mock.patch.object(ytmusic, "search_artists", return_value=[]):
            self.lib.findArtist("Nobody At All")
        self.assertEqual(self.found, [])
        self.assertEqual(len(self.toasts), 1)
        self.assertIn("Nobody At All", self.toasts[0])


if __name__ == "__main__":
    unittest.main()
