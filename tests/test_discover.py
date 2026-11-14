"""Search page recommendations (run: python -m unittest discover tests)."""

import unittest
from unittest import mock

from senada import discover, ytmusic


def song(vid, artist_id="UCa", album_id="", album=""):
    return {"uri": f"yt:track:{vid}", "id": vid, "name": vid, "artists": "Artist " + artist_id,
            "artistId": artist_id, "albumId": album_id, "album": album, "imageSmall": "s", "image": "m"}


def card(kind, cid):
    return {"kind": kind, "id": cid, "uri": f"senada:{kind}:{cid}", "name": cid}


HOME = [{"title": "Quick picks", "tracks": [song(f"h{i}") for i in range(10)], "cards": []},
        {"title": "New releases", "tracks": [],
         "cards": [card("album", f"MPREb_h{i}") for i in range(6)] + [card("artist", f"UCh{i}") for i in range(6)]}]


class Seeds(unittest.TestCase):
    def test_artists_heard_most_and_the_last_songs(self):
        history = [song("a1", "UCx"), song("a2", "UCy"), song("a3", "UCx")]
        liked = [song("l1", "UCz"), song("l2", "UCz"), song("l3", "UCz"), {"uri": "spotify:track:1", "artistId": "sp1"}]
        picked = discover.seeds(history, liked)
        self.assertEqual(picked["artists"], ["UCx", "UCz", "UCy"])  # history counts double
        self.assertEqual(picked["songs"], ["a1", "a2"])

    def test_nothing_heard_yet(self):
        self.assertEqual(discover.seeds([], []), {"artists": [], "songs": []})


class Build(unittest.TestCase):
    def test_from_listening(self):
        radio = {"s1": [song("s1"), song("r1", album_id="MPREb_r1", album="R1"), song("played"), song("r2")],
                 "s2": [song("s2"), song("q1"), song("r1")]}
        pages = {"UCx": {"albums": [card("album", "MPREb_x")],
                         "sections": [{"cards": [card("artist", "UCrel1"), card("playlist", "PL1"), card("artist", "UCx")]}]}}
        with mock.patch.object(ytmusic, "up_next", lambda v: radio[v]), \
             mock.patch.object(ytmusic, "artist", lambda a: pages[a]), \
             mock.patch.object(ytmusic, "home", side_effect=AssertionError("home shelves were given")):
            out = discover.build({"artists": ["UCx"], "songs": ["s1", "s2"]}, HOME, {"yt:track:played"})
        uris = [t["uri"] for t in out["tracks"]]
        self.assertEqual(uris[:3], ["yt:track:r1", "yt:track:q1", "yt:track:r2"])  # the two radios in turn, no repeats
        self.assertNotIn("yt:track:played", uris)
        self.assertNotIn("yt:track:s1", uris)
        self.assertEqual(out["artists"][0]["id"], "UCrel1")  # the seed artist itself is left out
        self.assertNotIn("UCx", [a["id"] for a in out["artists"]])
        self.assertEqual([a["id"] for a in out["albums"]][:2], ["MPREb_x", "MPREb_r1"])
        self.assertTrue(out["personal"])
        self.assertLessEqual(len(out["tracks"]), discover.LIMIT)

    def test_a_new_listener_gets_what_is_popular(self):
        with mock.patch.object(ytmusic, "home", return_value=HOME):
            out = discover.build({"artists": [], "songs": []}, [], set())
        self.assertFalse(out["personal"])
        self.assertEqual(len(out["tracks"]), 10)
        self.assertEqual(len(out["albums"]), 6)
        self.assertEqual(len(out["artists"]), 6)

    def test_a_failing_lookup_is_filled_from_home(self):
        def broken(_):
            raise ytmusic.YTMusicError("offline")
        with mock.patch.object(ytmusic, "up_next", broken), mock.patch.object(ytmusic, "artist", broken):
            out = discover.build({"artists": ["UCx"], "songs": ["s1"]}, HOME, set())
        self.assertEqual(out["tracks"][0]["uri"], "yt:track:h0")

    def test_nothing_at_all_is_an_error(self):
        with mock.patch.object(ytmusic, "home", return_value=[]):
            with self.assertRaises(ytmusic.YTMusicError):
                discover.build({"artists": [], "songs": []}, [], set())


if __name__ == "__main__":
    unittest.main()
