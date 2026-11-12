"""Offline tests for senada.matching (run: python -m unittest discover tests)."""

import unittest

from senada import matching as m

ATV, OMV, UGC = "MUSIC_VIDEO_TYPE_ATV", "MUSIC_VIDEO_TYPE_OMV", "MUSIC_VIDEO_TYPE_UGC"


def cand(vid, name, artists, seconds, video_type=ATV, album=""):
    return {"id": vid, "name": name, "artists": artists, "durationMs": seconds * 1000,
            "videoType": video_type, "album": album}


def best(source, candidates):
    return m.rank(source, candidates)[0]


class Normalisation(unittest.TestCase):
    def test_clean_title_strips_decoration_and_credits(self):
        self.assertEqual(m.clean_title("Hati‐Hati di Jalan (Official Music Video)"), "hati hati di jalan")
        self.assertEqual(m.clean_title("Bohemian Rhapsody - Remastered 2011"), "bohemian rhapsody")
        self.assertEqual(m.clean_title("Ya Hit (feat. Drake, Travis Scott)"), "ya hit")
        self.assertEqual(m.clean_title("lovely (with Khalid)"), "lovely")

    def test_bare_with_stays_in_the_title(self):
        self.assertEqual(m.clean_title("Dance With Me"), "dance with me")
        self.assertEqual(m.featured("Dance With Me"), [])
        self.assertEqual(m.featured("lovely (with Khalid)"), ["khalid"])

    def test_version_tags(self):
        self.assertEqual(m.version_tags("TULUS - Hati-Hati di Jalan (Karaoke Original Key)"), {"karaoke"})
        self.assertEqual(m.version_tags("Layla (Acoustic; Live at MTV Unplugged)"), {"acoustic", "live"})
        self.assertEqual(m.version_tags("Bohemian Rhapsody - Remastered 2011"), set())
        self.assertIn("slowed", m.version_tags("Untitled (Slowed + Reverb)"))

    def test_search_query_drops_noise(self):
        self.assertEqual(m.search_query({"name": "Bohemian Rhapsody - Remastered 2011", "artists": "Queen"}),
                         "queen bohemian rhapsody")
        self.assertEqual(m.search_query({"name": "Ya Hit (feat. Drake)", "artists": "Future, Drake"}), "future ya hit")


class Scoring(unittest.TestCase):
    source = {"name": "Hati-Hati di Jalan", "artists": "Tulus", "durationMs": 242000}

    def test_official_beats_karaoke_cover_and_lyrics(self):
        candidates = [
            cand("k", "TULUS - Hati-Hati di Jalan (Karaoke Original Key)", "WNF Production", 247, UGC),
            cand("c", "Hati - Hati Di jalan - Tulus REGGAE COVER", "HVMBLE REGGAE", 258, UGC),
            cand("l", "Hati-Hati di Jalan - Tulus | Lirik Lagu", "Indolirik", 243, UGC),
            cand("o", "Hati-Hati di Jalan", "Tulus", 242, ATV, "Manusia"),
        ]
        ranked = m.rank(self.source, candidates)
        self.assertEqual(ranked[0]["id"], "o")
        scores = {c["id"]: c["match"]["score"] for c in ranked}
        self.assertGreaterEqual(scores["o"], m.ACCEPT)
        self.assertLess(scores["k"], m.MINIMUM)
        self.assertLess(scores["c"], m.MINIMUM)

    def test_same_title_by_another_artist_is_not_accepted(self):
        src = {"name": "Creep", "artists": "Radiohead", "durationMs": 238000}
        other = m.score(src, cand("x", "Creep", "Rain Paris", 235))
        self.assertLess(other["score"], m.ACCEPT)
        self.assertGreater(m.score(src, cand("r", "Creep", "Radiohead", 239))["score"], other["score"] + 30)

    def test_live_source_prefers_live_recording(self):
        src = {"name": "Hotel California - Live On MTV, 1994", "artists": "Eagles", "durationMs": 427000}
        top = best(src, [cand("s", "Hotel California", "Eagles", 391),
                         cand("l", "Hotel California (Live)", "Eagles", 425, OMV)])
        self.assertEqual(top["id"], "l")

    def test_studio_source_avoids_live_and_remix(self):
        src = {"name": "Blinding Lights", "artists": "The Weeknd", "durationMs": 200000}
        top = best(src, [cand("live", "Blinding Lights (Live)", "The Weeknd", 205, OMV),
                         cand("rmx", "Blinding Lights (Chromatics Remix)", "The Weeknd", 202),
                         cand("ok", "Blinding Lights", "The Weeknd", 201)])
        self.assertEqual(top["id"], "ok")

    def test_far_duration_is_disqualified(self):
        result = m.score(self.source, cand("long", "Hati-Hati di Jalan", "Tulus", 3600))
        self.assertTrue(result["disqualified"])
        self.assertLess(result["score"], m.MINIMUM)

    def test_similar_title_loses_without_duration(self):
        src = {"name": "Evaluasi", "artists": "Hindia", "durationMs": 0}
        self.assertEqual(best(src, [cand("x", "Evakuasi", "Hindia", 208), cand("y", "Evaluasi", "Hindia", 197)])["id"], "y")

    def test_featured_credit_does_not_hurt_the_official_upload(self):
        src = {"name": "lovely (with Khalid)", "artists": "Billie Eilish, Khalid", "durationMs": 200000}
        top = best(src, [cand("fan", "Billie Eilish - lovely (with Khalid) (Lyrics)", "POPuLuv", 201, UGC),
                         cand("ok", "lovely", "Billie Eilish, Khalid", 201)])
        self.assertEqual(top["id"], "ok")

    def test_rank_drops_duplicate_ids(self):
        ranked = m.rank(self.source, [cand("a", "Hati-Hati di Jalan", "Tulus", 242)] * 3)
        self.assertEqual(len(ranked), 1)


if __name__ == "__main__":
    unittest.main()
