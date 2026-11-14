"""Your phone as a remote: a small web page on this computer, opened by scanning a QR code.

Off until switched on in Settings → Phone remote. Then Senada listens on the local network
(port 8765, or the next free one) and the page shows the song with play / pause, previous /
next, seeking, the volume and like. Every address carries a random key (kept in the settings,
so a phone's bookmark keeps working; "New link" makes another one and the old link stops),
so only someone with the QR code or the link can use it. No app on the phone, no account.

The server runs on its own thread; commands go to the player on the Qt thread through a
queued signal, and the page reads a copy of the player's state made on the Qt thread.
"""

import json
import logging
import secrets
import socket
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PySide6.QtCore import Property, QObject, Qt, Signal, Slot

from .i18n import tr
from .remote_page import PAGE

try:
    import segno
except ImportError:  # no QR code: the link is still shown
    segno = None

logger = logging.getLogger("senada.remote")

PORT = 8765
PORTS_TRIED = 10
COMMANDS = ("toggle", "next", "previous", "seek", "volume", "shuffle", "repeat", "like")


def lan_address() -> str:
    """This computer's address on the local network (no packet is sent)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
    except OSError:
        try:
            return socket.gethostbyname(socket.gethostname())
        except OSError:
            return "127.0.0.1"


def page_html() -> bytes:
    return PAGE.encode("utf-8")


def snapshot(state: dict, position: int) -> dict:
    image = state.get("imageLarge") or state.get("image") or ""
    return {
        "hasTrack": bool(state.get("hasTrack")), "name": state.get("name", ""), "artists": state.get("artists", ""),
        "album": state.get("album", ""), "image": image if image.startswith("http") else "",
        "isPlaying": bool(state.get("isPlaying")), "position": int(position or 0),
        "duration": int(state.get("durationMs") or 0), "volume": int(state.get("volume") or 0),
        "shuffle": bool(state.get("shuffle")), "repeat": state.get("repeat", "off"), "liked": bool(state.get("liked")),
    }


class _Handler(BaseHTTPRequestHandler):
    remote = None  # set on a subclass per server

    def log_message(self, fmt, *args):  # no console noise
        logger.debug("remote: " + fmt, *args)

    def _authorized(self) -> bool:
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
        return secrets.compare_digest((query.get("k") or [""])[0], self.remote.key)

    def _send(self, code, body: bytes, kind="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        route = urllib.parse.urlsplit(self.path).path
        if not self._authorized():
            self._send(403, b"This link is not valid any more: scan the QR code in Senada again.", "text/plain; charset=utf-8")
        elif route == "/":
            self._send(200, page_html(), "text/html; charset=utf-8")
        elif route == "/api/state":
            self._send(200, json.dumps(self.remote.state()).encode())
        else:
            self._send(404, b"{}")

    def do_POST(self):
        if not self._authorized() or urllib.parse.urlsplit(self.path).path != "/api/cmd":
            self._send(403, b"{}")
            return
        try:
            length = min(int(self.headers.get("Content-Length") or 0), 4096)
            body = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            self._send(400, b"{}")
            return
        cmd = body.get("cmd")
        if cmd not in COMMANDS:
            self._send(400, b"{}")
            return
        self.remote.command.emit(cmd, body.get("value"))
        self._send(200, b"{}")


class Remote(QObject):
    changed = Signal()
    toast = Signal(str)
    command = Signal(str, object)   # from the server thread, handled on the Qt thread

    def __init__(self, player, settings, parent=None):
        super().__init__(parent)
        self.player = player
        self.settings = settings
        self._server = None
        self._port = 0
        self._lock = threading.Lock()
        self._snap = {}
        self.command.connect(self._on_command, Qt.ConnectionType.QueuedConnection)
        player.stateChanged.connect(self._refresh)
        player.positionChanged.connect(self._refresh)
        self._refresh()
        if self.settings["remote"]:
            self._start()

    # ---- the player's side --------------------------------------------------------------------

    @property
    def key(self) -> str:
        key = self.settings["remote_key"]
        if not key:
            key = secrets.token_urlsafe(12)
            self.settings["remote_key"] = key
        return key

    def state(self) -> dict:
        with self._lock:
            return dict(self._snap)

    def _refresh(self):
        snap = snapshot(self.player.state, self.player.position)
        with self._lock:
            self._snap = snap

    def _on_command(self, cmd, value):
        p = self.player
        if cmd == "toggle":
            p.togglePlay()
        elif cmd == "next":
            p.next()
        elif cmd == "previous":
            p.previous()
        elif cmd == "seek" and isinstance(value, (int, float)):
            p.seek(int(value))
        elif cmd == "volume" and isinstance(value, (int, float)):
            p.setVolume(int(value))
        elif cmd == "shuffle":
            p.toggleShuffle()
        elif cmd == "repeat":
            p.cycleRepeat()
        elif cmd == "like":
            p.toggleLike()

    # ---- the server ---------------------------------------------------------------------------

    def _start(self):
        if self._server is not None:
            return True
        _ = self.key  # made now, so the link is known before the first phone asks
        handler = type("Handler", (_Handler,), {"remote": self})
        for port in range(PORT, PORT + PORTS_TRIED):
            try:
                server = ThreadingHTTPServer(("0.0.0.0", port), handler)
                break
            except OSError:
                continue
        else:
            self.toast.emit(tr("The phone remote could not start: no free port"))
            return False
        server.daemon_threads = True
        self._server, self._port = server, port
        threading.Thread(target=server.serve_forever, name="senada-remote", daemon=True).start()
        logger.info("phone remote on port %d", port)
        return True

    def _stop(self):
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server, self._port = None, 0

    def close(self):
        self._stop()

    # ---- QML ----------------------------------------------------------------------------------

    @Property(bool, notify=changed)
    def enabled(self):
        return self._server is not None

    @enabled.setter
    def enabled(self, on):
        on = bool(on)
        if on == self.enabled:
            return
        ok = self._start() if on else (self._stop() or True)
        self.settings["remote"] = on and ok
        self.changed.emit()

    @Property(str, notify=changed)
    def url(self):
        if not self._port:
            return ""
        return f"http://{lan_address()}:{self._port}/?k={self.key}"

    @Property(str, notify=changed)
    def qr(self):
        """The link as a QR code (an SVG data URI for an Image), or "" without segno."""
        if not self._port or segno is None:
            return ""
        return segno.make(self.url, error="m").svg_data_uri(scale=6, border=2, dark="#000000", light="#ffffff")

    @Slot()
    def newLink(self):
        """A new key: the old link (and phones that kept it) stop working."""
        self.settings["remote_key"] = secrets.token_urlsafe(12)
        self.changed.emit()
