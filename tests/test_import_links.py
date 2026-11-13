"""Which links import what, offline (run: python -m unittest discover tests)."""

import unittest
from unittest import mock

from senada import library, ytmusic
from senada.library import ImportLinkError, _yt_link, youtube_collection


class Links(unittest.TestCase):
    def test_youtube_music_links(self):
        self.assertEqual(_yt_link("https://music.youtube.com/playlist?list=PLabc&si=x"), ("playlist", "PLabc"))
        self.assertEqual(_yt_link("https://www.youtube.com/playlist?list=PLabc"), ("playlist", "PLabc"))
        self.assertEqual(_yt_link("music.youtube.com/browse/MPREb_abc"), ("album", "MPREb_abc"))

    def test_song_played_from_a_playlist_imports_the_playlist(self):
        link = "https://music.youtube.com/watch?v=abc&list=PLxyz"
        self.assertEqual(_yt_link(link), ("track", "abc"))  # search: the song
        self.assertEqual(_yt_link(link, list_first=True), ("playlist", "PLxyz"))  # import: the playlist


class Collection(unittest.TestCase):
    def test_account_lists_and_mixes_are_explained(self):
        with mock.patch.object(ytmusic, "playlist") as fetch:
            for cid in ("LM", "WL", "RDAMVMabc"):
                with self.assertRaises(ImportLinkError):
                    youtube_collection("playlist", cid)
            fetch.assert_not_called()

    def test_editorial_playlist_imports_with_its_link(self):
        page = {"name": "Lofi", "tracks": [{"uri": "yt:track:a"}]}
        with mock.patch.object(ytmusic, "playlist", return_value=page) as fetch:
            got = youtube_collection("playlist", "RDCLAK5uy_abc")
        fetch.assert_called_once_with("RDCLAK5uy_abc", limit=library.YT_IMPORT_LIMIT)
        self.assertEqual(got["source"], "https://music.youtube.com/playlist?list=RDCLAK5uy_abc")

    def test_private_or_missing_playlist(self):
        with mock.patch.object(ytmusic, "playlist", return_value={"name": "Playlist", "tracks": []}):
            with self.assertRaises(ImportLinkError):
                youtube_collection("playlist", "PLprivate")
        with mock.patch.object(ytmusic, "playlist", side_effect=ytmusic.YTMusicError("refused (HTTP 404)")):
            with self.assertRaises(ImportLinkError):
                youtube_collection("playlist", "PLgone")


if __name__ == "__main__":
    unittest.main()
