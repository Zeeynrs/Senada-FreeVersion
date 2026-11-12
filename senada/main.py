import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQuickControls2 import QQuickStyle

from .catalog import Catalog
from .config import BIN_DIR, IS_WINDOWS, Settings
from .engine import AudioEngine
from .resolver import AudioResolver
from .library import Library
from .lyrics import Lyrics
from .player import Player
from .session import Session
from .store import LocalStore
from .updater import Updater
from .visualizer import Visualizer
from .worker import Async

ROOT = Path(__file__).resolve().parent.parent


def _ensure_user_bins_in_path():
    """Put bundled tools (bin/) and ~/.local/bin on PATH, also when started from a shortcut."""
    path_parts = os.environ.get("PATH", "").split(os.pathsep) if os.environ.get("PATH") else []
    for extra in (Path.home() / ".local" / "bin", BIN_DIR):
        s = str(extra)
        if extra.is_dir() and s not in path_parts:
            path_parts.insert(0, s)
    os.environ["PATH"] = os.pathsep.join(path_parts)


def main():
    _ensure_user_bins_in_path()
    if not IS_WINDOWS and os.environ.get("WAYLAND_DISPLAY"):
        os.environ.setdefault("QT_QPA_PLATFORM", "wayland;xcb")
    if IS_WINDOWS:
        try:  # own taskbar group and icon instead of python.exe's
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Senada.MusicPlayer")
        except (AttributeError, OSError):
            pass
    # windows get an alpha channel so the "Transparan" glass mode can show the desktop through
    QQuickWindow.setDefaultAlphaBuffer(True)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Senada")
    app.setOrganizationName("senada")
    app.setDesktopFileName("senada")  # Wayland app_id, for Hyprland window rules
    app.setWindowIcon(QIcon(str(ROOT / "data" / "senada.svg")))
    app.setFont(QFont(["Google Sans Flex", "Google Sans", "Segoe UI Variable Text", "Segoe UI",
                       "Noto Sans", "sans-serif"], 10))
    QQuickStyle.setStyle("Basic")
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    keepalive = QTimer()  # lets Python handle Ctrl+C while Qt's loop runs
    keepalive.timeout.connect(lambda: None)
    keepalive.start(500)

    settings = Settings()
    worker = Async()
    store = LocalStore()
    catalog = Catalog(store)
    session = Session(settings, worker)
    audio_engine = AudioEngine()
    resolver = AudioResolver()
    player = Player(worker, audio_engine, resolver, settings, store, catalog)
    library = Library(store, catalog, worker, session, player, resolver)
    library.toast.connect(session.toast)
    lyrics = Lyrics(player, worker)
    visualizer = Visualizer()
    updater = Updater(worker)
    updater.toast.connect(session.toast)
    restarting = False

    def request_restart():
        nonlocal restarting
        restarting = True
        app.quit()

    updater.restartRequested.connect(request_restart)

    def on_quit():
        audio_engine.quit()
        visualizer.stop()
        player.stop()

    app.aboutToQuit.connect(on_quit)

    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    ctx = engine.rootContext()
    for name, obj in (("session", session), ("player", player), ("library", library),
                      ("lyrics", lyrics), ("visualizer", visualizer),
                      ("updater", updater)):
        ctx.setContextProperty(name, obj)
    engine.load(str(ROOT / "qml" / "Main.qml"))
    if not engine.rootObjects():
        sys.exit("Senada: gagal memuat antarmuka (lihat pesan QML di atas)")

    window = engine.rootObjects()[0]
    session.set_window(window)
    try:
        from .mpris import Mpris
        mpris = Mpris(player, lambda: (window.show(), window.raise_(), window.requestActivate()), app.quit)
    except Exception as e:  # MPRIS is optional: no dbus-python or no session bus
        print(f"MPRIS tidak aktif: {e}", file=sys.stderr)
        mpris = None

    library.refreshAll()
    player.start()

    ret = app.exec()
    if restarting:
        args = [sys.executable, str(ROOT / "run.py"), *sys.argv[1:]]
        if IS_WINDOWS:  # execv on Windows spawns a child and returns, so start it detached and exit
            import subprocess
            subprocess.Popen(args, close_fds=True)
            sys.exit(0)
        os.execv(sys.executable, args)
    sys.exit(ret)
