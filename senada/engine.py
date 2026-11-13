"""Local audio engine: a headless mpv driven over its JSON IPC.

mpv plays YouTube Music audio with no ads on the system output: normally from a stream
address Senada already looked up (see streams.py), else from a watch link through mpv's own
yt-dlp hook. The next track can be lined up in mpv's playlist so it starts without a gap.
The IPC endpoint is a Unix socket on Linux and a named pipe on Windows;
QLocalSocket speaks both, and runs on the Qt event loop so no reader thread is needed.
"""

import atexit
import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, Signal
from PySide6.QtNetwork import QLocalSocket

from .childproc import popen_tied
from .config import BIN_DIR, CACHE_DIR, IS_WINDOWS, NO_WINDOW
from .i18n import tr

logger = logging.getLogger("senada.engine")

CONNECT_TRIES = 60       # x 100 ms while mpv starts up
MAX_PENDING = 50         # commands kept while not connected yet


def find_tool(name: str) -> str | None:
    """A helper program (mpv, yt-dlp): bundled copy first, then PATH, then usual install places."""
    exe = name + (".exe" if IS_WINDOWS else "")
    candidates = [BIN_DIR / exe]
    found = shutil.which(name)
    if found:
        candidates.append(Path(found))
    if IS_WINDOWS:
        local = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        candidates += [local / "Programs" / name / exe, Path.home() / "scoop" / "shims" / exe,
                       Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / name / exe]
    else:
        candidates += [Path("/usr/bin") / name, Path("/usr/local/bin") / name, Path.home() / ".local" / "bin" / name]
    return next((str(p) for p in candidates if p.is_file()), None)


class AudioEngine(QObject):
    positionChanged = Signal(int)    # position in ms
    durationChanged = Signal(int)    # duration in ms
    stateChanged = Signal(bool)      # is_playing
    trackEnded = Signal()            # track finished playing
    loadFailed = Signal()            # the file could not be opened or broke off
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        if IS_WINDOWS:
            self.ipc_path = rf"\\.\pipe\senada-mpv-{os.getpid()}"
        else:
            # short path: Unix sockets are limited to ~108 characters
            runtime = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
            self.ipc_path = os.path.join(runtime, f"senada-mpv-{os.getpid()}.sock")
        self.proc = None
        self._buf = b""
        self._pending: list[bytes] = []
        self._tries = 0
        self._is_playing = False
        self._paused = False
        self._idle = True  # mpv with nothing loaded reports pause=false, which isn't "playing"
        self._last_pos_ms = 0
        self._pos_step = 0       # emit the position only after it moved this many ms (0: every update)
        self._emitted_pos = -1
        self._job = None         # Windows job object that ends mpv together with Senada
        self._duration_ms = 0
        self._queued = ""    # url appended to mpv's playlist, played by mpv itself when the current file ends
        self._advanced = ""  # queued url mpv has already moved on to; the next play() of it is a no-op

        self.sock = QLocalSocket(self)
        self.sock.connected.connect(self._on_connected)
        self.sock.readyRead.connect(self._on_ready_read)
        self.sock.errorOccurred.connect(self._on_socket_error)
        self._retry = QTimer(self)
        self._retry.setInterval(100)
        self._retry.setSingleShot(True)
        self._retry.timeout.connect(self._try_connect)

        self._start_mpv()
        atexit.register(self.quit)

    # ---- process & connection ---------------------------------------------------

    def _start_mpv(self):
        if not IS_WINDOWS and os.path.exists(self.ipc_path):
            try:
                os.remove(self.ipc_path)
            except OSError:
                pass

        mpv_bin = find_tool("mpv")
        if not mpv_bin:
            self._fail(tr("mpv was not found. Install mpv (Windows: put mpv.exe in Senada's bin/ folder or on PATH)."))
            return
        cmd = [
            mpv_bin,
            "--idle=yes",
            "--no-video",
            "--no-terminal",
            f"--input-ipc-server={self.ipc_path}",
            "--ytdl=yes",
            "--ytdl-format=bestaudio[ext=m4a]/bestaudio/best",
            "--demuxer-max-bytes=30M",
            "--demuxer-readahead-secs=45",
            "--audio-pitch-correction=yes",
            "--gapless-audio=weak",
            "--prefetch-playlist=yes",  # opens the queued next track while the current one is ending
        ]
        # stream addresses Senada resolved itself never go through the (slow) yt-dlp hook
        # (the pattern is matched against the address after its "https://")
        script_opts = ["ytdl_hook-exclude=^[^/]*googlevideo%.com/"]
        ytdlp = find_tool("yt-dlp")
        if ytdlp:
            script_opts.append(f"ytdl_hook-ytdl_path={ytdlp}")
        cmd.append("--script-opts=" + ",".join(script_opts))
        try:
            # tied to Senada: mpv ends with it even after a crash or a kill
            self.proc, self._job = popen_tied(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                              stdin=subprocess.DEVNULL, creationflags=NO_WINDOW)
        except OSError as e:
            self._fail(tr("Could not start mpv: {error}", error=e))
            return
        self._tries = 0
        self._retry.start()

    def _try_connect(self):
        if self.sock.state() != QLocalSocket.LocalSocketState.UnconnectedState:
            return
        self._tries += 1
        self.sock.connectToServer(self.ipc_path)

    def _on_socket_error(self, _err):
        if self.sock.state() == QLocalSocket.LocalSocketState.ConnectedState:
            return
        if self.proc is not None and self.proc.poll() is None and self._tries < CONNECT_TRIES:
            self._retry.start()  # mpv hasn't opened its IPC endpoint yet
        elif self._tries >= CONNECT_TRIES:
            self._fail(tr("Could not connect to the audio engine."))

    def _on_connected(self):
        for cmd in (["observe_property", 1, "time-pos"],
                    ["observe_property", 2, "pause"],
                    ["observe_property", 3, "duration"],
                    ["observe_property", 4, "idle-active"]):
            self._send_command(cmd)
        pending, self._pending = self._pending, []
        for line in pending:
            self.sock.write(line)
        self.sock.flush()

    def _fail(self, msg: str):
        logger.error(msg)
        # emitted later so the player has connected its slots by then
        QTimer.singleShot(0, lambda: self.errorOccurred.emit(msg))

    # ---- position updates ------------------------------------------------------------

    def set_position_step(self, ms: int):
        """mpv reports the position ~16 times a second. While nobody is looking at Senada,
        passing on only every `ms` milliseconds is enough (lyrics, MPRIS) and saves the
        work every update causes in the interface. 0 passes on every update."""
        self._pos_step = max(0, int(ms))
        if self._pos_step == 0 and self._emitted_pos != self._last_pos_ms:
            self._emitted_pos = self._last_pos_ms  # catch up at once when the window comes back
            self.positionChanged.emit(self._last_pos_ms)

    def _on_time_pos(self, ms: int):
        self._last_pos_ms = ms
        # seeks and new tracks jump by more than the step, so they still come through at once
        if self._pos_step and self._emitted_pos >= 0 and abs(ms - self._emitted_pos) < self._pos_step:
            return
        self._emitted_pos = ms
        self.positionChanged.emit(ms)

    # ---- protocol -------------------------------------------------------------------

    def _send_command(self, cmd_args):
        line = (json.dumps({"command": cmd_args}) + "\n").encode("utf-8")
        if self.sock.state() == QLocalSocket.LocalSocketState.ConnectedState:
            self.sock.write(line)
            self.sock.flush()
        elif len(self._pending) < MAX_PENDING:
            self._pending.append(line)

    def _on_ready_read(self):
        self._buf += bytes(self.sock.readAll())
        *lines, self._buf = self._buf.split(b"\n")
        for line in lines:
            if not line.strip():
                continue
            try:
                self._handle_message(json.loads(line))
            except (ValueError, UnicodeDecodeError):
                pass

    def _handle_message(self, msg: dict):
        event = msg.get("event")
        if event == "property-change":
            name = msg.get("name")
            data = msg.get("data")
            if name == "time-pos" and data is not None:
                self._on_time_pos(int(data * 1000))
            elif name == "pause":
                self._paused = bool(data)
                self._update_playing()
            elif name == "idle-active":
                self._idle = bool(data)
                self._update_playing()
            elif name == "duration" and data is not None:
                d_ms = int(data * 1000)
                self._duration_ms = d_ms
                self.durationChanged.emit(d_ms)

        elif event == "end-file":
            reason = msg.get("reason")
            if reason == "eof" and self._queued:
                # mpv is already starting the queued file: playback goes on without a gap
                self._advanced, self._queued = self._queued, ""
                self._duration_ms = 0  # the next file reports its own
                self.trackEnded.emit()
            elif reason in ("eof", "stop"):
                self._is_playing = False
                self.stateChanged.emit(False)
                if reason == "eof":
                    self.trackEnded.emit()
            elif reason == "error":
                self._advanced = self._queued = ""
                self.loadFailed.emit()

        elif event == "playback-restart":  # a file started (or a seek finished)
            self._idle = False
            self._update_playing()

    def _update_playing(self):
        playing = not self._paused and not self._idle
        if playing != self._is_playing:
            self._is_playing = playing
            self.stateChanged.emit(playing)

    # ---- public API -------------------------------------------------------------------

    def play(self, url: str):
        if url and url == self._advanced:  # mpv moved on to this queued file by itself: it is playing
            self._advanced = ""
            if self._duration_ms:
                self.durationChanged.emit(self._duration_ms)
            self._send_command(["set_property", "pause", False])
            return
        self._advanced = self._queued = ""  # "replace" drops the rest of mpv's playlist
        self._duration_ms = 0
        self._last_pos_ms = 0
        self._send_command(["loadfile", url, "replace"])
        self._send_command(["set_property", "pause", False])

    def queue_next(self, url: str):
        """Line up the file mpv plays by itself, gapless, when the current one ends ("" for none)."""
        if url == self._queued:
            return
        if self._queued:
            self._send_command(["playlist-clear"])  # keeps only the file that is playing
        self._queued = url
        if url:
            self._send_command(["loadfile", url, "append"])

    def pause(self):
        self._send_command(["set_property", "pause", True])

    def resume(self):
        self._send_command(["set_property", "pause", False])

    def toggle(self):
        self._send_command(["cycle", "pause"])

    def seek(self, ms: int):
        self._send_command(["seek", max(0, ms / 1000.0), "absolute"])

    def set_volume(self, pct: int):
        self._send_command(["set_property", "volume", max(0, min(100, pct))])

    def stop(self):
        self._advanced = self._queued = ""
        self._send_command(["stop"])
        self._is_playing = False
        self.stateChanged.emit(False)

    def quit(self):
        if self.proc is None:
            return
        try:
            self._send_command(["quit"])
            self.sock.waitForBytesWritten(200)
            self.sock.disconnectFromServer()
        except RuntimeError:  # Qt object already gone at interpreter exit
            pass
        try:
            self.proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
        except OSError:
            pass
        self.proc = None
        if not IS_WINDOWS and os.path.exists(self.ipc_path):
            try:
                os.remove(self.ipc_path)
            except OSError:
                pass
