"""Local Audio Engine using mpv JSON IPC.
Streams YouTube/YouTube Music audio with zero ads, hardware output, and PipeWire/Pulse integration.
"""

import atexit
import json
import logging
import os
import shutil
import socket
import subprocess
import threading
import time
from pathlib import Path
from PySide6.QtCore import QObject, Signal

from .config import CACHE_DIR

logger = logging.getLogger("senada.engine")


class AudioEngine(QObject):
    positionChanged = Signal(int)    # position in ms
    durationChanged = Signal(int)    # duration in ms
    stateChanged = Signal(bool)      # is_playing
    trackEnded = Signal()            # track finished playing
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.sock_path = str(CACHE_DIR / "mpv.sock")
        self.proc = None
        self.sock = None
        self._reader_running = False
        self._reader_thread = None
        self._is_playing = False
        self._last_pos_ms = 0
        self._duration_ms = 0

        self._ensure_cache_dir()
        self._start_mpv()
        atexit.register(self.quit)

    def _ensure_cache_dir(self):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def _find_mpv(self) -> str:
        bin_path = shutil.which("mpv")
        if not bin_path:
            for p in ("/usr/bin/mpv", "/usr/local/bin/mpv", Path.home() / ".local/bin/mpv"):
                if Path(p).exists():
                    return str(p)
        return bin_path or "mpv"

    def _start_mpv(self):
        if os.path.exists(self.sock_path):
            try:
                os.remove(self.sock_path)
            except OSError:
                pass

        mpv_bin = self._find_mpv()
        cmd = [
            mpv_bin,
            "--idle=yes",
            "--no-video",
            f"--input-ipc-server={self.sock_path}",
            "--ytdl=yes",
            "--ytdl-format=bestaudio[ext=m4a]/bestaudio/best",
            "--demuxer-max-bytes=30M",
            "--demuxer-readahead-secs=45",
            "--audio-pitch-correction=yes",
            "--gapless-audio=weak",
        ]

        try:
            self.proc = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
            )
        except Exception as e:
            logger.error(f"Failed to start mpv: {e}")
            self.errorOccurred.emit(f"Gagal menjalankan mpv: {e}")
            return

        # Wait for socket to appear
        for _ in range(30):
            if os.path.exists(self.sock_path):
                break
            time.sleep(0.05)

        self._connect_socket()

    def _connect_socket(self):
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(self.sock_path)
            self._reader_running = True
            self._reader_thread = threading.Thread(target=self._reader_loop, daemon=True)
            self._reader_thread.start()

            # Observe properties
            self._send_command(["observe_property", 1, "time-pos"])
            self._send_command(["observe_property", 2, "pause"])
            self._send_command(["observe_property", 3, "duration"])
        except Exception as e:
            logger.error(f"Socket connection error: {e}")
            self.errorOccurred.emit("Koneksi audio engine gagal.")

    def _send_command(self, cmd_args):
        if not self.sock:
            return
        try:
            line = json.dumps({"command": cmd_args}) + "\n"
            self.sock.sendall(line.encode("utf-8"))
        except Exception as e:
            logger.debug(f"Send command error: {e}")

    def _reader_loop(self):
        buf = ""
        while self._reader_running:
            try:
                data = self.sock.recv(4096)
                if not data:
                    break
                buf += data.decode("utf-8", errors="ignore")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    if line.strip():
                        try:
                            msg = json.loads(line)
                            self._handle_message(msg)
                        except json.JSONDecodeError:
                            pass
            except Exception:
                break

    def _handle_message(self, msg: dict):
        event = msg.get("event")
        if event == "property-change":
            name = msg.get("name")
            data = msg.get("data")
            if name == "time-pos" and data is not None:
                ms = int(data * 1000)
                self._last_pos_ms = ms
                self.positionChanged.emit(ms)
            elif name == "pause":
                playing = not bool(data)
                if playing != self._is_playing:
                    self._is_playing = playing
                    self.stateChanged.emit(playing)
            elif name == "duration" and data is not None:
                d_ms = int(data * 1000)
                self._duration_ms = d_ms
                self.durationChanged.emit(d_ms)

        elif event == "end-file":
            reason = msg.get("reason")
            if reason in ("eof", "stop"):
                self._is_playing = False
                self.stateChanged.emit(False)
                if reason == "eof":
                    self.trackEnded.emit()

        elif event == "playback-restart":
            self._is_playing = True
            self.stateChanged.emit(True)

    # Public API
    def play(self, url: str):
        self._duration_ms = 0
        self._last_pos_ms = 0
        self._send_command(["loadfile", url, "replace"])
        self._send_command(["set_property", "pause", False])

    def pause(self):
        self._send_command(["set_property", "pause", True])

    def resume(self):
        self._send_command(["set_property", "pause", False])

    def toggle(self):
        self._send_command(["cycle", "pause"])

    def seek(self, ms: int):
        sec = max(0, ms / 1000.0)
        self._send_command(["seek", sec, "absolute"])

    def set_volume(self, pct: int):
        val = max(0, min(100, pct))
        self._send_command(["set_property", "volume", val])

    def stop(self):
        self._send_command(["stop"])
        self._is_playing = False
        self.stateChanged.emit(False)

    def quit(self):
        self._reader_running = False
        try:
            self._send_command(["quit"])
        except Exception:
            pass
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None
        if self.proc:
            try:
                self.proc.terminate()
            except Exception:
                pass
            self.proc = None
        if os.path.exists(self.sock_path):
            try:
                os.remove(self.sock_path)
            except OSError:
                pass
