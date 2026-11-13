"""Discord Rich Presence: the activity built from the player, and the IPC protocol against a
stand-in for the Discord app (run: python -m unittest discover tests)."""

import json
import os
import struct
import time
import unittest
from unittest import mock

from PySide6.QtCore import QCoreApplication, QEventLoop, QObject, QTimer, Signal
from PySide6.QtNetwork import QLocalServer

from senada import discord as dc

APP = QCoreApplication.instance() or QCoreApplication([])

SONG = {"hasTrack": True, "isPlaying": True, "name": "Hati-Hati di Jalan", "artists": "Tulus",
        "album": "Manusia", "durationMs": 240_000, "uri": "yt:track:abc-123",
        "imageLarge": "https://lh3.googleusercontent.com/cover=w544"}


def wait_for(cond, ms=3000):
    end = time.monotonic() + ms / 1000
    while time.monotonic() < end and not cond():
        loop = QEventLoop()
        QTimer.singleShot(20, loop.quit)
        loop.exec()
    return cond()


class FakePlayer(QObject):
    stateChanged = Signal()
    positionChanged = Signal()

    def __init__(self, state=None, position=0):
        super().__init__()
        self.state = dict(state or SONG)
        self.position = position


class FakeSettings(dict):
    def __getitem__(self, key):
        return self.get(key)


class Activity(unittest.TestCase):
    def build(self, state=SONG, pos=60_000, speed=1.0, show_paused=False, now=1_000_000.0):
        return dc.build_activity(state, pos, speed, show_paused, now)

    def test_song_with_progress_bar_cover_and_button(self):
        a = self.build()
        self.assertEqual(a["type"], dc.ACTIVITY_LISTENING)
        self.assertEqual((a["details"], a["state"]), ("Hati-Hati di Jalan", "Tulus"))
        self.assertEqual(a["timestamps"], {"start": 1_000_000 - 60, "end": 1_000_000 - 60 + 240})
        self.assertEqual(a["assets"]["large_image"], SONG["imageLarge"])
        self.assertEqual(a["assets"]["large_text"], "Manusia")
        self.assertEqual(a["buttons"][0]["url"], "https://music.youtube.com/watch?v=abc-123")
        self.assertLessEqual(len(a["buttons"][0]["label"]), 32)

    def test_tempo_changes_how_long_the_song_takes(self):
        a = self.build(speed=2.0)
        self.assertEqual(a["timestamps"], {"start": 1_000_000 - 30, "end": 1_000_000 - 30 + 120})

    def test_nothing_without_a_song(self):
        self.assertIsNone(self.build(state={"hasTrack": False}))

    def test_paused_hidden_or_shown_without_a_bar(self):
        paused = {**SONG, "isPlaying": False}
        self.assertIsNone(self.build(state=paused))
        a = self.build(state=paused, show_paused=True)
        self.assertNotIn("timestamps", a)
        self.assertTrue(a["state"].startswith("Tulus · "))

    def test_local_covers_are_left_out(self):
        a = self.build(state={**SONG, "imageLarge": "file:///C:/covers/x.jpg", "image": "", "imageSmall": ""})
        self.assertNotIn("large_image", a["assets"])

    def test_text_fits_discord_limits(self):
        self.assertEqual(len(dc.clip("x" * 300)), 128)
        self.assertEqual(len(dc.clip("A")), 2)
        self.assertEqual(dc.clip(""), "")

    def test_same_activity_ignores_small_clock_drift(self):
        a = self.build(now=1_000_000.0)
        self.assertTrue(dc.same_activity(a, self.build(now=1_000_001.0)))
        self.assertFalse(dc.same_activity(a, self.build(pos=120_000)))
        self.assertFalse(dc.same_activity(a, None))


class FakeDiscord(QObject):
    """Answers the handshake with READY (or closes, like Discord does for a bad client id)
    and keeps every frame it gets."""

    def __init__(self, name, reject=False):
        super().__init__()
        self.frames, self.reject, self.conn, self.buf = [], reject, None, b""
        self.server = QLocalServer(self)
        QLocalServer.removeServer(name)
        assert self.server.listen(name), self.server.errorString()
        self.server.newConnection.connect(self._accept)

    def _accept(self):
        self.conn = self.server.nextPendingConnection()
        self.conn.readyRead.connect(self._read)

    def send(self, op, payload):
        self.conn.write(dc.frame(op, payload))
        self.conn.flush()

    def _read(self):
        self.buf += bytes(self.conn.readAll())
        while len(self.buf) >= 8:
            op, n = struct.unpack("<II", self.buf[:8])
            if len(self.buf) < 8 + n:
                return
            msg, self.buf = json.loads(self.buf[8:8 + n]), self.buf[8 + n:]
            self.frames.append((op, msg))
            if op == dc.OP_HANDSHAKE:
                if self.reject:
                    self.send(dc.OP_CLOSE, {"code": 4000, "message": "Invalid Client ID"})
                    self.conn.disconnectFromServer()
                else:
                    self.send(dc.OP_FRAME, {"cmd": "DISPATCH", "evt": "READY", "data": {"v": 1}})

    def activities(self):
        return [m["args"] for op, m in self.frames if op == dc.OP_FRAME and m.get("cmd") == "SET_ACTIVITY"]


@mock.patch.multiple(dc, SETTLE_MS=20, MIN_INTERVAL_MS=50)
class Protocol(unittest.TestCase):
    def setUp(self):
        self.name = f"senada-test-discord-{os.getpid()}-{id(self)}"
        self.player = FakePlayer()
        self.settings = FakeSettings(discord_presence=True, discord_show_paused=False)
        self.keep = []

    def presence(self, paths=None):
        p = dc.DiscordPresence(self.player, self.settings, app_id="123456789", paths=paths or [self.name])
        self.keep.append(p)  # (a collected presence takes its socket with it)
        self.addCleanup(lambda: p.sock.abort())
        return p

    def test_handshake_then_the_song(self):
        server = FakeDiscord(self.name)
        p = self.presence(paths=["senada-test-nothing-here", self.name])  # the first endpoint is skipped
        self.assertTrue(wait_for(lambda: server.activities()))
        self.assertEqual(server.frames[0], (dc.OP_HANDSHAKE, {"v": 1, "client_id": "123456789"}))
        self.assertEqual(p.status, "connected")
        args = server.activities()[0]
        self.assertEqual(args["pid"], os.getpid())
        self.assertEqual(args["activity"]["details"], SONG["name"])

    def test_pause_clears_and_nothing_is_sent_twice(self):
        server = FakeDiscord(self.name)
        self.presence()
        self.assertTrue(wait_for(lambda: server.activities()))
        self.player.stateChanged.emit()  # nothing visible changed
        self.player.state["isPlaying"] = False
        self.player.stateChanged.emit()
        self.assertTrue(wait_for(lambda: len(server.activities()) >= 2))
        wait_for(lambda: False, 200)
        self.assertEqual(len(server.activities()), 2)
        self.assertNotIn("activity", server.activities()[1])

    def test_a_seek_redraws_the_bar(self):
        server = FakeDiscord(self.name)
        self.presence()
        self.assertTrue(wait_for(lambda: server.activities()))
        self.player.position = 200_000
        self.player.positionChanged.emit()
        self.assertTrue(wait_for(lambda: len(server.activities()) >= 2))
        ts = server.activities()[1]["activity"]["timestamps"]
        self.assertAlmostEqual(time.time() - ts["start"], 200, delta=2)

    def test_turning_it_off_clears_the_status(self):
        server = FakeDiscord(self.name)
        p = self.presence()
        self.assertTrue(wait_for(lambda: server.activities()))
        p.enabled = False
        self.assertTrue(wait_for(lambda: len(server.activities()) >= 2))
        self.assertNotIn("activity", server.activities()[-1])
        self.assertEqual(p.status, "off")
        self.assertFalse(self.settings["discord_presence"])

    def test_answers_ping(self):
        server = FakeDiscord(self.name)
        self.presence()
        self.assertTrue(wait_for(lambda: server.activities()))
        server.send(dc.OP_PING, {"n": 1})
        self.assertTrue(wait_for(lambda: (dc.OP_PONG, {"n": 1}) in server.frames))

    def test_rejected_client_id(self):
        self.keep.append(FakeDiscord(self.name, reject=True))
        p = self.presence()
        self.assertTrue(wait_for(lambda: p.status == "rejected"))

    def test_discord_not_running(self):
        p = self.presence(paths=["senada-test-nothing-here"])
        self.assertTrue(wait_for(lambda: p.status == "missing"))

    def test_off_by_default_and_without_an_app_id(self):
        self.assertFalse(dc.DiscordPresence(self.player, FakeSettings(discord_presence=True), app_id="").enabled)
        settings = FakeSettings()
        settings.update({"discord_presence": False})
        p = dc.DiscordPresence(self.player, settings, app_id="1", paths=[self.name])
        self.assertEqual(p.status, "off")


if __name__ == "__main__":
    unittest.main()
