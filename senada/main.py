import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface
from PySide6.QtQuickControls2 import QQuickStyle

from . import logs
from .catalog import Catalog
from .config import BIN_DIR, FROZEN, IS_WINDOWS, ROOT, Settings
from .engine import AudioEngine
from .resolver import AudioResolver
from .library import Library
from .downloads import Downloads
from .discord import DiscordPresence
from .effects import AudioEffects
from .instance import Instance, ask_running_to_show
from .lyrics import Lyrics
from .player import Player
from .session import Session
from .store import LocalStore
from .updater import Updater
from .visualizer import Visualizer
from .worker import Async


def _ensure_user_bins_in_path():
    """Put bundled tools (bin/) and ~/.local/bin on PATH, also when started from a shortcut."""
    path_parts = os.environ.get("PATH", "").split(os.pathsep) if os.environ.get("PATH") else []
    for extra in (Path.home() / ".local" / "bin", BIN_DIR):
        s = str(extra)
        if extra.is_dir() and s not in path_parts:
            path_parts.insert(0, s)
    os.environ["PATH"] = os.pathsep.join(path_parts)


def main():
    logs.setup()
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
    if IS_WINDOWS:
        # Qt's default Direct3D renderer does not hand that alpha to the Windows compositor, so
        # "Transparan" showed a flat grey/black sheet; OpenGL does (QSG_RHI_BACKEND still overrides)
        QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.OpenGL)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Senada")
    app.setOrganizationName("senada")
    app.setDesktopFileName("senada")  # Wayland app_id, for Hyprland window rules
    app.setWindowIcon(QIcon(str(ROOT / "data" / "senada.png")))
    app.setFont(QFont(["Google Sans Flex", "Google Sans", "Segoe UI Variable Text", "Segoe UI",
                       "Noto Sans", "sans-serif"], 10))
    QQuickStyle.setStyle("Basic")
    # one Senada at a time: a second start brings the running one forward (it may be in the tray)
    if ask_running_to_show():
        sys.exit(0)
    instance = Instance()
    # Ctrl+C, and the system asking Senada to close (logout, `kill`, closed terminal):
    # quit the normal way so mpv and the visualizer are stopped too
    # (through session.quit, so closing the window does not just send it to the tray)
    for sig in ("SIGINT", "SIGTERM", "SIGHUP"):
        if hasattr(signal, sig) and not (IS_WINDOWS and sig != "SIGINT"):
            signal.signal(getattr(signal, sig), lambda *_: session.quit())
    keepalive = QTimer()  # lets Python handle Ctrl+C while Qt's loop runs
    keepalive.timeout.connect(lambda: None)
    keepalive.start(500)

    settings = Settings()
    worker = Async()
    store = LocalStore()
    catalog = Catalog(store)
    session = Session(settings, worker)
    instance.showRequested.connect(session.showRequested)
    audio_engine = AudioEngine()
    resolver = AudioResolver()
    downloads = Downloads(resolver)
    catalog.downloads = downloads
    player = Player(worker, audio_engine, resolver, settings, store, catalog, downloads)
    library = Library(store, catalog, worker, session, player, resolver)
    library.toast.connect(session.toast)
    downloads.toast.connect(session.toast)

    def on_language():  # text made in Python follows too: pages, Home shelves, update status
        catalog.clear()
        library.refreshAll()
        updater.changed.emit()
        lyrics.refreshExtra()

    session.languageChanged.connect(on_language)
    lyrics = Lyrics(player, worker, settings, downloads)
    effects = AudioEffects(settings, audio_engine)
    discord = DiscordPresence(player, settings, effects)
    visualizer = Visualizer()
    updater = Updater(worker)
    updater.toast.connect(session.toast)
    restarting = False

    def request_restart():
        nonlocal restarting
        restarting = True
        session.quit()

    updater.restartRequested.connect(request_restart)
    updater.quitRequested.connect(session.quit)
    media_controls = None

    def on_quit():
        audio_engine.quit()
        visualizer.stop()
        player.stop()
        if media_controls is not None:
            media_controls.close()
        instance.close()  # before a restart starts the new Senada, which would find this one

    app.aboutToQuit.connect(on_quit)

    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    ctx = engine.rootContext()
    for name, obj in (("session", session), ("player", player), ("library", library),
                      ("lyrics", lyrics), ("visualizer", visualizer), ("downloads", downloads), ("effects", effects), ("discord", discord),
                      ("updater", updater)):
        ctx.setContextProperty(name, obj)
    engine.load(str(ROOT / "qml" / "Main.qml"))
    if not engine.rootObjects():
        sys.exit("Senada: the interface could not be loaded (see the QML messages above)")

    window = engine.rootObjects()[0]
    session.set_window(window)
    try:
        from .mpris import Mpris
        mpris = Mpris(player, session.showRequested.emit, session.quit)
    except Exception as e:  # MPRIS is optional: no dbus-python or no session bus
        print(f"MPRIS is off: {e}", file=sys.stderr)
        mpris = None
    if IS_WINDOWS:
        try:
            from .smtc import MediaControls
            media_controls = MediaControls(player)
        except Exception as e:  # optional too: the winrt packages are missing, or Windows says no
            print(f"Windows media controls are off: {e}", file=sys.stderr)

    library.refreshAll()
    player.start()

    ret = app.exec()
    # the interface goes first: torn down after the objects it shows (lyrics, player, …),
    # its bindings would read them as null and fill the log with errors
    del window, ctx
    del engine
    if restarting:
        if FROZEN:  # Senada.exe restarts itself
            args = [sys.executable, *sys.argv[1:]]
        else:
            args = [sys.executable, str(ROOT / "run.py"), *sys.argv[1:]]
        if IS_WINDOWS:  # execv on Windows spawns a child and returns, so start it detached and exit
            import subprocess
            subprocess.Popen(args, close_fds=True)
            sys.exit(0)
        os.execv(sys.executable, args)
    sys.exit(ret)
