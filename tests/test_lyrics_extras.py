"""Word-timed lyrics (BetterLyrics TTML, KuGou KRC), romanization and translation
(run: python -m unittest discover tests)."""

import base64
import unittest
import zlib
from unittest import mock

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import i18n, lyrics
from tests.test_recovery import SyncWorker

APP = QCoreApplication.instance() or QCoreApplication([])

TTML = """<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-internal"
 xmlns:ttm="http://www.w3.org/ns/ttml#metadata" itunes:timing="Word" xml:lang="ja"><head><metadata>
<iTunesMetadata xmlns="http://music.apple.com/lyric-ttml-internal">
<translations><translation type="subtitle" xml:lang="en-US"><text for="L1">If only it were a dream</text></translation></translations>
<transliterations><transliteration xml:lang="ja-Latn"><text for="L1"><span xmlns="http://www.w3.org/ns/ttml" begin="1.2" end="1.6">yume</span> <span xmlns="http://www.w3.org/ns/ttml" begin="1.6" end="2.1">nara</span><span xmlns="http://www.w3.org/ns/ttml" begin="2.1" end="2.6">ba</span></text></transliteration></transliterations>
</iTunesMetadata></metadata></head>
<body><div><p begin="1.2" end="2.6" itunes:key="L1"><span begin="1.2" end="1.6">夢</span><span begin="1.6" end="2.1">なら</span><span begin="2.1" end="2.6">ば</span></p>
<p begin="1:02.500" end="1:05" itunes:key="L2"><span begin="1:02.500" end="1:03">I</span> <span begin="1:03" end="1:03.400">been</span> <span begin="1:03.400" end="1:04">e</span><span begin="1:04" end="1:05">nough</span> <span ttm:role="x-bg"><span begin="1:04.5" end="1:05">ooh</span></span></p>
</div></body></tt>"""


def make_krc(text: str) -> str:
    packed = zlib.compress(text.encode("utf-8"))
    return base64.b64encode(b"krc1" + bytes(b ^ lyrics.KRC_KEY[i % 16] for i, b in enumerate(packed))).decode()


KRC = """[ti:Song]
[0,1500]<0,400,0>Song <400,400,0>- <800,700,0>Artist
[1600,2000]<0,500,0>Lyrics <500,500,0>by：<1000,1000,0>Someone
[5000,1800]<0,300,0>Hello <300,500,0>my <800,1000,0>friend
[9000,900]<0,900,0>再见
"""


class Ttml(unittest.TestCase):
    def setUp(self):
        self.data = lyrics.parse_ttml(TTML)
        self.first, self.second = self.data["lines"]

    def test_words_join_up_to_the_line(self):
        self.assertTrue(self.data["synced"])
        self.assertEqual(self.first["text"], "夢ならば")
        self.assertEqual(self.second["text"], "I been enough (ooh)")
        for line in (self.first, self.second):
            self.assertEqual("".join(w["text"] for w in line["words"]), line["text"])

    def test_times_in_ms_and_syllables_stay_one_word(self):
        self.assertEqual(self.second["t"], 62500)
        e, nough = self.second["words"][2:4]
        self.assertEqual((e["text"], e["t"], e["d"]), ("e", 63400, 600))
        self.assertEqual(nough["text"], "nough ")

    def test_romanization_and_translation_by_line(self):
        self.assertEqual(self.first["roman"], "yume naraba")
        self.assertEqual(self.first["trans"], "If only it were a dream")
        self.assertNotIn("roman", self.second)

    def test_clock_values(self):
        self.assertEqual([lyrics.ttml_ms(v) for v in ("27.395", "1:02.345", "0:01:02.345", "12.5s", "x")],
                         [27395, 62345, 62345, 12500, None])

    def test_line_timing_has_no_words(self):
        data = lyrics.parse_ttml(TTML.replace('itunes:timing="Word"', 'itunes:timing="Line"'))
        self.assertTrue(data["synced"])
        self.assertNotIn("words", data["lines"][0])
        self.assertEqual(data["lines"][1]["text"], "I been enough ooh")


class Krc(unittest.TestCase):
    def test_decoded_and_credits_left_out(self):
        data = lyrics.parse_krc(lyrics.decode_krc(make_krc(KRC)), {"name": "Song", "artists": "Artist"})
        self.assertEqual([l["text"] for l in data["lines"]], ["Hello my friend", "再见"])
        hello = data["lines"][0]
        self.assertEqual([(w["t"], w["d"]) for w in hello["words"]], [(5000, 300), (5300, 500), (5800, 1000)])

    def test_not_a_krc(self):
        with self.assertRaises(ValueError):
            lyrics.decode_krc(base64.b64encode(b"nope").decode())

    def test_kugou_steps(self):
        track = {"name": "Hello", "artists": "Band", "durationMs": 200000}

        def answer(url, *args, **kwargs):
            if "mobilecdn" in url:
                return {"data": {"info": [{"hash": "h1", "songname": "Hello", "singername": "Band", "duration": 200}]}}
            if "krcs.kugou" in url:
                self.assertIn("hash=h1", url)
                return {"candidates": [{"id": "7", "accesskey": "k"}]}
            return {"content": make_krc("[1000,500]<0,500,0>Hello")}

        with mock.patch.object(lyrics, "_get_json", side_effect=answer):
            data = lyrics.fetch_kugou(track)
        self.assertEqual(data["lines"][0]["words"][0]["text"], "Hello")


class Korean(unittest.TestCase):
    def test_revised_romanization(self):
        cases = {"사랑해요": "saranghaeyo", "감사합니다": "gamsahamnida", "있어요": "isseoyo",
                 "한국어": "hangugeo", "설날": "seollal", "신라": "silla", "I love 너": "I love neo"}
        for hangul, roman in cases.items():
            self.assertEqual(lyrics.romanize_korean(hangul), roman, hangul)


class Translate(unittest.TestCase):
    def test_one_line_out_for_each_line_in(self):
        reply = [[["Halo\n", "Hello\n"], ["teman", "friend"]], None, "en"]
        with mock.patch.object(lyrics, "_get_json", return_value=reply):
            self.assertEqual(lyrics.translate_lines(["Hello", "friend"], "id"), ["Halo", "teman"])

    def test_already_in_that_language(self):
        with mock.patch.object(lyrics, "_get_json", return_value=[[["Halo", "Halo"]], None, "id"]):
            self.assertEqual(lyrics.translate_lines(["Halo"], "id"), [""])

    def test_lines_that_ran_together_are_refused(self):
        with mock.patch.object(lyrics, "_get_json", return_value=[[["Halo teman", "x"]], None, "en"]):
            with self.assertRaises(ValueError):
                lyrics.translate_lines(["Hello", "friend"], "id")


class FakePlayer(QObject):
    trackChanged = Signal()
    positionChanged = Signal()

    def __init__(self):
        super().__init__()
        self.state, self.position = {}, 0


class Settings(dict):
    def __getitem__(self, key):
        return self.get(key)


class UnderEachLine(unittest.TestCase):
    def setUp(self):
        self.settings = Settings()
        self.lyrics = lyrics.Lyrics(FakePlayer(), SyncWorker(), self.settings)
        self.lyrics._key = ("yt:track:x", "auto")
        self.lines = [{"t": 0, "text": "사랑해", "trans": "I love you"}, {"t": 900, "text": "Hello"}]
        i18n.set_language("id")
        self.addCleanup(i18n.set_language, "en")

    def show(self):
        self.lyrics._set(self.lyrics._key, {"synced": True, "lines": self.lines}, "ready")
        return [l.get("sub") for l in self.lyrics.lines]

    def test_off_by_default(self):
        self.assertEqual(self.show(), [None, None])

    def test_korean_is_romanized(self):
        self.lyrics.extra = "roman"
        self.assertEqual(self.show(), ["saranghae", None])
        self.assertEqual(self.settings["lyrics_extra"], "roman")

    def test_given_translation_without_going_online(self):
        self.lyrics.extra = "trans"
        with mock.patch.object(lyrics, "translate_lines") as online:
            self.assertEqual(self.show(), ["I love you", None])
        online.assert_not_called()

    def test_online_translation_into_the_interface_language(self):
        self.lyrics.extra = "trans"
        self.lyrics.onlineTranslation = True
        with mock.patch.object(lyrics, "translate_lines", return_value=["Aku cinta kamu", "Halo"]) as online:
            self.assertEqual(self.show(), ["Aku cinta kamu", "Halo"])
        online.assert_called_once_with(["사랑해", "Hello"], "id")

    def test_nothing_is_translated_while_the_lyrics_load(self):
        self.lyrics.extra = "trans"
        self.lyrics.onlineTranslation = True
        with mock.patch.object(lyrics, "translate_lines", return_value=[]) as online:
            self.lyrics._set(self.lyrics._key, {}, "loading")
        online.assert_not_called()


class AutoOrder(unittest.TestCase):
    def test_word_timed_sources_come_first(self):
        self.assertEqual(lyrics.AUTO_ORDER[0], "betterlyrics")
        self.assertEqual(set(lyrics.AUTO_ORDER), set(lyrics.FETCHERS))


if __name__ == "__main__":
    unittest.main()
