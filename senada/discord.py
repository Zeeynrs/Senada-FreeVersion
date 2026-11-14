"""Discord Rich Presence: "Listening to Senada" with the song on the user's Discord profile.

Senada talks to the Discord desktop app on this computer over its local IPC endpoint
(a named pipe on Windows, a Unix socket on Linux), the same way the official SDK does:
no login and no extra library. Every message is a frame of an opcode and a length
(both little-endian uint32) followed by that many bytes of JSON. After a handshake with
the app's client id, SET_ACTIVITY shows the song: title, artists, cover, a progress bar
and a link to the song.

Discord allows about five activity updates in 20 seconds, so updates are put together
and sent at most every few seconds, and only when something visible changed. When
Discord is not running Senada tries again now and then; it never waits on Discord.
"""

import json
import logging
import os
import struct
import time
import uuid

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
from PySide6.QtNetwork import QLocalSocket

from .config import DISCORD_APP_ID, IS_WINDOWS
from .i18n import tr
from .links import track_link

logger = logging.getLogger("senada.discord")

OP_HANDSHAKE, OP_FRAME, OP_CLOSE, OP_PING, OP_PONG = range(5)
ACTIVITY_LISTENING = 2
LOGO_URL = "https://raw.githubusercontent.com/Zeeynrs/Senada/main/qml/icons/logo.png"
MIN_INTERVAL_MS = 4000   # between two activity updates (Discord: 5 per 20 s)
SETTLE_MS = 600          # wait this long for more changes before sending (a skip sends one update)
RETRY_MS = 15000         # look for Discord again after it was not found or went away
REJECTED_RETRY_MS = 300000  # Discord refused the handshake (wrong client id): try again much later
SEEK_SLACK_S = 3         # the bar is redrawn when the song is this far from where Discord thinks


def ipc_paths() -> list[str]:
    """Where the Discord app (or Canary, PTB, Flatpak, Snap, Vesktop) listens."""
    names = [f"discord-ipc-{i}" for i in range(10)]
    if IS_WINDOWS:
        return names  # QLocalSocket opens \\.\pipe\<name>
    bases = [os.environ.get(k) for k in ("XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP")] + ["/tmp"]
    subdirs = ("", "app/com.discordapp.Discord", "app/com.discordapp.DiscordCanary",
               ".flatpak/dev.vencord.Vesktop/xdg-run", "snap.discord", "snap.discord-canary")
    paths = []
    for base in dict.fromkeys(b for b in bases if b):
        for sub in subdirs:
            for name in names:
                path = os.path.join(base, sub, name)
                if path not in paths and os.path.exists(path):
                    paths.append(path)
    return paths


def frame(op: int, payload: dict) -> bytes:
    data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return struct.pack("<II", op, len(data)) + data


def clip(text: str, limit: int = 128) -> str:
    """Discord takes 2 to 128 characters for text fields."""
    text = " ".join((text or "").split())
    if len(text) > limit:
        text = text[:limit - 1].rstrip() + "…"
    return text.ljust(2, "\u2800") if text else ""


def build_activity(state: dict, position_ms: int, speed: float, show_paused: bool, now: float) -> dict | None:
    """The activity for this player state, or None to show nothing."""
    name = state.get("name") or ""
    if not state.get("hasTrack") or not name:
        return None
    playing = bool(state.get("isPlaying"))
    if not playing and not show_paused:
        return None
    artists = state.get("artists") or ""
    activity = {"type": ACTIVITY_LISTENING, "details": clip(name)}
    status = artists if playing else (f"{artists} · {tr('Paused')}" if artists else tr("Paused"))
    if status:
        activity["state"] = clip(status)
    duration = int(state.get("durationMs") or 0)
    if playing and duration > 0:
        speed = speed if speed > 0 else 1.0
        start = now - position_ms / 1000 / speed
        activity["timestamps"] = {"start": int(start), "end": int(start + duration / 1000 / speed)}
    cover = next((state.get(k) for k in ("imageLarge", "image", "imageSmall")
                  if (state.get(k) or "").startswith("https://")), "")
    assets = {"small_image": LOGO_URL, "small_text": "Senada"}
    if cover:
        assets["large_image"] = cover
        album = clip(state.get("album") or "")
        if album:
            assets["large_text"] = album
    activity["assets"] = assets
    link = track_link(state)
    if link:
        label = tr("Listen on YouTube Music") if "youtube.com" in link else tr("Open on Spotify")
        activity["buttons"] = [{"label": clip(label, 32), "url": link}]
    return activity


def same_activity(a: dict | None, b: dict | None) -> bool:
    """Equal apart from timestamps that moved by less than the slack (the clock ticked on)."""
    if a is None or b is None:
        return a is b
    if {k: v for k, v in a.items() if k != "timestamps"} != {k: v for k, v in b.items() if k != "timestamps"}:
        return False
    ta, tb = a.get("timestamps"), b.get("timestamps")
    if not ta or not tb:
        return ta == tb
    return abs(ta["start"] - tb["start"]) < SEEK_SLACK_S and abs(ta["end"] - tb["end"]) < SEEK_SLACK_S


class DiscordPresence(QObject):
    changed = Signal()

    def __init__(self, player, settings, effects=None, app_id: str = DISCORD_APP_ID, paths=None, parent=None):
        super().__init__(parent)
        self.player = player
        self.settings = settings
        self.effects = effects
        self.app_id = app_id
        self._paths = paths          # fixed endpoints (tests); None: ipc_paths()
        self._candidates: list[str] = []
        self._status = "off"         # off, searching, connected, missing, rejected
        self._buf = b""
        self._sent: dict | None = None   # the activity Discord shows now
        self._sent_any = False
        self._last_send = 0.0

        self.sock = QLocalSocket(self)
        self.sock.connected.connect(self._on_connected)
        self.sock.readyRead.connect(self._on_ready_read)
        self.sock.errorOccurred.connect(self._on_error)
        self.sock.disconnected.connect(self._on_disconnected)
        self._retry = QTimer(self, singleShot=True, timeout=self._search)
        self._update = QTimer(self, singleShot=True, timeout=self._send_update)

        player.stateChanged.connect(self._schedule)
        player.positionChanged.connect(self._on_position)
        if effects is not None:
            effects.changed.connect(self._schedule)
        if self.enabled:
            QTimer.singleShot(0, self._search)

    # ---- settings (QML) --------------------------------------------------------------

    @Property(bool, constant=True)
    def available(self):
        """This build has a Discord application id."""
        return bool(self.app_id)

    def _get_enabled(self):
        return bool(self.settings["discord_presence"]) and self.available

    def _set_enabled(self, on):
        self.settings["discord_presence"] = bool(on)
        self.changed.emit()
        if self.enabled:
            self._search()
        else:
            self._stop()

    enabled = Property(bool, _get_enabled, _set_enabled, notify=changed)

    def _get_show_paused(self):
        return bool(self.settings["discord_show_paused"])

    def _set_show_paused(self, on):
        self.settings["discord_show_paused"] = bool(on)
        self.changed.emit()
        self._schedule()

    showPaused = Property(bool, _get_show_paused, _set_show_paused, notify=changed)

    @Property(str, notify=changed)
    def status(self):
        return self._status

    def _set_status(self, status):
        if status != self._status:
            self._status = status
            self.changed.emit()

    # ---- connection ------------------------------------------------------------------

    def _search(self):
        """Try the endpoints one after another (the next one when one fails)."""
        if not self.enabled or self.sock.state() != QLocalSocket.LocalSocketState.UnconnectedState:
            return
        if not self._candidates:
            self._candidates = list(self._paths if self._paths is not None else ipc_paths())
            if not self._candidates:
                self._set_status("missing")
                self._retry.start(RETRY_MS)
                return
        self._set_status("searching")
        self.sock.connectToServer(self._candidates.pop(0))

    def _on_error(self, _err):
        if self.sock.state() == QLocalSocket.LocalSocketState.ConnectedState or self._status != "searching":
            return
        if self._candidates:
            QTimer.singleShot(0, self._search)
        else:
            self._set_status("missing")
            self._retry.start(RETRY_MS)

    def _on_connected(self):
        self._buf = b""
        self._write(OP_HANDSHAKE, {"v": 1, "client_id": self.app_id})

    def _on_disconnected(self):
        self._candidates = []
        self._sent, self._sent_any = None, False
        if self._status in ("connected", "searching"):
            logger.info("Discord went away")
            self._set_status("missing")
        if self.enabled:
            self._retry.start(REJECTED_RETRY_MS if self._status == "rejected" else RETRY_MS)

    def _stop(self):
        self._retry.stop()
        self._update.stop()
        if self.sock.state() == QLocalSocket.LocalSocketState.ConnectedState and self._status == "connected":
            self._send_activity(None)  # clear it at once rather than when Discord notices the closed pipe
            self.sock.flush()
        self._set_status("off")
        self.sock.abort()
        self._candidates = []
        self._sent, self._sent_any = None, False

    def _write(self, op, payload):
        self.sock.write(frame(op, payload))
        self.sock.flush()

    def _on_ready_read(self):
        self._buf += bytes(self.sock.readAll())
        while len(self._buf) >= 8:
            op, length = struct.unpack("<II", self._buf[:8])
            if len(self._buf) < 8 + length:
                return
            body, self._buf = self._buf[8:8 + length], self._buf[8 + length:]
            try:
                msg = json.loads(body) if body else {}
            except ValueError:
                msg = {}
            self._handle(op, msg)

    def _handle(self, op, msg):
        if op == OP_PING:
            self._write(OP_PONG, msg)
        elif op == OP_CLOSE:  # e.g. an unknown client id
            logger.warning("Discord closed the connection: %s", msg.get("message") or msg)
            self._set_status("rejected")
            self.sock.disconnectFromServer()
        elif op == OP_FRAME:
            if msg.get("evt") == "READY":
                logger.info("connected to Discord")
                self._set_status("connected")
                self._last_send = 0.0
                self._schedule()
            elif msg.get("evt") == "ERROR":
                logger.warning("Discord: %s", (msg.get("data") or {}).get("message", msg))

    # ---- activity --------------------------------------------------------------------

    def _speed(self):
        return float(self.effects.tempo) if self.effects is not None else 1.0

    def _current(self):
        return build_activity(self.player.state, self.player.position, self._speed(), self.showPaused, time.time())

    def _schedule(self):
        if self._status != "connected" or self._update.isActive():
            return
        wait = max(SETTLE_MS, int(MIN_INTERVAL_MS - (time.monotonic() - self._last_send) * 1000))
        self._update.start(wait)

    def _on_position(self):
        """A seek (or a stall) moves the song away from Discord's bar: draw the bar again."""
        ts = (self._sent or {}).get("timestamps")
        if not ts or self._update.isActive():
            return
        shown = (time.time() - ts["start"]) * self._speed()
        if abs(shown - self.player.position / 1000) > SEEK_SLACK_S:
            self._schedule()

    def _send_update(self):
        if self._status != "connected":
            return
        activity = self._current()
        if self._sent_any and same_activity(activity, self._sent):
            return
        self._send_activity(activity)

    def _send_activity(self, activity):
        args = {"pid": os.getpid()}
        if activity is not None:
            args["activity"] = activity
        self._write(OP_FRAME, {"cmd": "SET_ACTIVITY", "args": args, "nonce": uuid.uuid4().hex})
        self._sent, self._sent_any = activity, True
        self._last_send = time.monotonic()

    @Slot()
    def retry(self):
        """Look for Discord now (the settings page's button)."""
        if self.enabled and self._status != "connected":
            self._retry.stop()
            self.sock.abort()
            self._candidates = []
            self._search()
