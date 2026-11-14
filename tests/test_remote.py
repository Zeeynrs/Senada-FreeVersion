"""The phone remote (run: python -m unittest discover tests)."""

import json
import time
import unittest
import urllib.error
import urllib.request
from unittest import mock

from PySide6.QtCore import QCoreApplication, QObject, Signal

from senada import remote

APP = QCoreApplication.instance() or QCoreApplication([])


class Settings(dict):
    def __getitem__(self, key):
        return self.get(key)


class FakePlayer(QObject):
    stateChanged = Signal()
    positionChanged = Signal()

    def __init__(self):
        super().__init__()
        self.state = {"hasTrack": True, "isPlaying": True, "name": "Untitled", "artists": "Rex Orange County",
                      "imageLarge": "https://example.com/c.jpg", "durationMs": 135000, "volume": 70, "repeat": "off"}
        self.position = 48000
        self.calls = []

    def togglePlay(self): self.calls.append("toggle")
    def next(self): self.calls.append("next")
    def previous(self): self.calls.append("previous")
    def seek(self, ms): self.calls.append(("seek", ms))
    def setVolume(self, v): self.calls.append(("volume", v))
    def toggleShuffle(self): self.calls.append("shuffle")
    def cycleRepeat(self): self.calls.append("repeat")
    def toggleLike(self): self.calls.append("like")


def until(check, seconds=3):
    end = time.time() + seconds
    while not check() and time.time() < end:
        APP.processEvents()
        time.sleep(0.01)
    return check()


class Server(unittest.TestCase):
    def setUp(self):
        p = mock.patch.object(remote, "PORT", 18765)
        p.start()
        self.addCleanup(p.stop)
        self.player = FakePlayer()
        self.settings = Settings(remote=False, remote_key="")
        self.r = remote.Remote(self.player, self.settings)
        self.addCleanup(self.r.close)
        self.r.enabled = True
        self.base = f"http://127.0.0.1:{self.r._port}"
        self.key = self.settings["remote_key"]

    def get(self, path):
        return urllib.request.urlopen(self.base + path, timeout=5)

    def test_on_and_off_is_remembered_and_a_key_is_made(self):
        self.assertTrue(self.r.enabled)
        self.assertTrue(self.settings["remote"])
        self.assertGreaterEqual(len(self.key), 12)
        self.assertIn(f"?k={self.key}", self.r.url)
        if remote.segno is not None:
            self.assertTrue(self.r.qr.startswith("data:image/svg+xml"))
        self.r.enabled = False
        self.assertFalse(self.settings["remote"])
        self.assertEqual(self.r.url, "")

    def test_the_page_and_the_state_need_the_key(self):
        with self.assertRaises(urllib.error.HTTPError) as e:
            self.get("/api/state?k=wrong")
        self.assertEqual(e.exception.code, 403)
        page = self.get(f"/?k={self.key}").read().decode()
        self.assertIn("<title>Senada</title>", page)
        state = json.loads(self.get(f"/api/state?k={self.key}").read())
        self.assertEqual((state["name"], state["position"], state["duration"]), ("Untitled", 48000, 135000))

    def test_commands_reach_the_player(self):
        def post(body, key=None):
            req = urllib.request.Request(f"{self.base}/api/cmd?k={key or self.key}", data=json.dumps(body).encode(),
                                         method="POST")
            return urllib.request.urlopen(req, timeout=5)

        post({"cmd": "toggle"})
        post({"cmd": "seek", "value": 60000})
        with self.assertRaises(urllib.error.HTTPError):
            post({"cmd": "rm -rf"})
        with self.assertRaises(urllib.error.HTTPError):
            post({"cmd": "next"}, key="wrong")
        self.assertTrue(until(lambda: len(self.player.calls) == 2))
        self.assertEqual(self.player.calls, ["toggle", ("seek", 60000)])

    def test_a_new_link_stops_the_old_one(self):
        old = self.key
        self.r.newLink()
        with self.assertRaises(urllib.error.HTTPError):
            self.get(f"/api/state?k={old}")
        self.get(f"/api/state?k={self.settings['remote_key']}")

    def test_local_covers_are_not_sent(self):
        self.player.state["imageLarge"] = "file:///C:/Users/me/cover.jpg"
        self.player.stateChanged.emit()
        self.assertEqual(self.r.state()["image"], "")


if __name__ == "__main__":
    unittest.main()
