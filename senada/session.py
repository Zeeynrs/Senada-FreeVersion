"""User-facing settings and small desktop helpers exposed to QML.

Senada needs no account: there is no login state here any more.
"""

import getpass
import os
import re
from pathlib import Path

from PySide6.QtCore import Property, QCoreApplication, QObject, QStandardPaths, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication, QImage, QRegion, QWindow

from . import i18n, island
from .config import LIBRARY_FILE, LOG_DIR


def _os_user_name() -> str:
    try:
        import pwd  # Unix only: the full name from /etc/passwd
        gecos = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
        if gecos:
            return gecos
    except (ImportError, KeyError, OSError, AttributeError):
        pass
    try:
        return getpass.getuser()
    except OSError:
        return ""


# full view styles (qml/ImmersivePlayer.qml); the first is the default
IMMERSIVE_STYLES = ("visualizer", "vinyl", "poster", "cinema")
# mini player styles (qml/MiniPlayer.qml); the first is the default
ISLAND_STYLES = ("classic", "wave", "lyrics", "glass")
ISLAND_DOCK_MIN, ISLAND_DOCK_MAX, ISLAND_DOCK_DEFAULT = 5, 15, 10
# settings that are one of a few words; the first of each is the default.
# lyrics_*: how lyrics look (qml/LyricLine.qml); player_bar: docked along the bottom, or floating
CHOICES = {
    "player_bar": ("docked", "floating"),
    "lyrics_size": ("medium", "small", "large"),
    "lyrics_font": ("sans", "serif"),
    "lyrics_align": ("left", "center"),
    "lyrics_highlight": ("bright", "glow", "karaoke"),
}

class Session(QObject):
    changed = Signal()
    languageChanged = Signal()
    toast = Signal(str)
    showRequested = Signal()  # bring the main window back (a second Senada was started)

    def __init__(self, settings, worker, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.worker = worker
        self._quitting = False
        worker.error.connect(self.toast)
        i18n.set_language(settings["language"])
        self._apply_theme()

    # ---- language ------------------------------------------------------------

    @Property(str, notify=languageChanged)
    def language(self):
        return i18n.language()

    @language.setter
    def language(self, value):
        if value in i18n.LANGUAGES and value != i18n.language():
            self.settings["language"] = i18n.set_language(value)
            self.languageChanged.emit()

    @Property("QVariantMap", notify=languageChanged)
    def translations(self):
        """English text -> current language, for the QML I18n singleton."""
        return i18n.table()

    # ---- theme -------------------------------------------------------------

    THEMES = ("system", "dark", "light")

    def _apply_theme(self):
        # lets the native title bar (Windows, some Linux desktops) follow the chosen theme
        scheme = {"dark": Qt.ColorScheme.Dark, "light": Qt.ColorScheme.Light}.get(self.settings["theme"],
                                                                                  Qt.ColorScheme.Unknown)
        try:
            QGuiApplication.styleHints().setColorScheme(scheme)
        except AttributeError:  # Qt older than 6.8
            pass

    # ---- glass ("liquid glass") look -------------------------------------------

    GLASS_MODES = ("off", "cover", "desktop")

    def set_window(self, window):
        """The main window, so the native see-through backdrop can follow the setting."""
        self._window = window
        self._apply_window_effects()

    def _apply_window_effects(self):
        window = getattr(self, "_window", None)
        if window is None:
            return
        from .window_effects import apply_backdrop
        apply_backdrop(window, self.glassMode == "desktop", self.settings["theme"])

    @Property(str, notify=changed)
    def glassMode(self):
        mode = self.settings["glass"]
        return mode if mode in self.GLASS_MODES else "off"

    @glassMode.setter
    def glassMode(self, value):
        if value in self.GLASS_MODES and value != self.settings["glass"]:
            self.settings["glass"] = value
            self._apply_window_effects()
            self.changed.emit()

    @Property(float, notify=changed)
    def glassOpacity(self):
        try:
            return max(0.3, min(0.9, float(self.settings["glass_opacity"])))
        except (TypeError, ValueError):
            return 0.62

    @glassOpacity.setter
    def glassOpacity(self, value):
        value = round(max(0.3, min(0.9, float(value))), 2)
        if value != self.settings["glass_opacity"]:
            self.settings["glass_opacity"] = value
            self.changed.emit()

    @Property(str, notify=changed)
    def themeMode(self):
        mode = self.settings["theme"]
        return mode if mode in self.THEMES else "system"

    @themeMode.setter
    def themeMode(self, value):
        if value in self.THEMES and value != self.settings["theme"]:
            self.settings["theme"] = value
            self._apply_theme()
            self._apply_window_effects()
            self.changed.emit()

    @Property(str, constant=True)
    def libraryPath(self):
        return str(LIBRARY_FILE)

    @Property(str, notify=changed)
    def displayName(self):
        return self.settings["display_name"] or _os_user_name()

    @displayName.setter
    def displayName(self, value):
        value = (value or "").strip()
        if value != self.settings["display_name"]:
            self.settings["display_name"] = value
            self.changed.emit()

    @Slot(str)
    def copy(self, text):
        QGuiApplication.clipboard().setText(text)
        self.toast.emit(i18n.tr("Copied to clipboard"))

    @Slot(str)
    def openUrl(self, url):
        QDesktopServices.openUrl(QUrl(url))

    # ---- pictures (shared lyrics) ------------------------------------------------------

    @Slot("QVariant")
    def copyImage(self, image):
        if isinstance(image, QImage) and not image.isNull():
            QGuiApplication.clipboard().setImage(image)
            self.toast.emit(i18n.tr("Picture copied: paste it in a chat or a story"))

    @Slot(str, result=str)
    def picturePath(self, name):
        """A file in Pictures/Senada named after `name` that does not exist yet."""
        pictures = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.PicturesLocation)
        folder = Path(pictures or Path.home()) / "Senada"
        folder.mkdir(parents=True, exist_ok=True)
        stem = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", name or "").strip(" .")[:120] or "Senada"
        path, n = folder / f"{stem}.png", 2
        while path.exists():
            path, n = folder / f"{stem} ({n}).png", n + 1
        return str(path)

    @Slot(str)
    def showFile(self, path):
        """Open the folder a file is in."""
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(Path(path).parent)))

    @Property(str, constant=True)
    def logPath(self):
        return str(LOG_DIR)

    @Slot()
    def openLogFolder(self):
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(LOG_DIR)))

    # ---- quitting and the tray -----------------------------------------------------

    @Property(bool)
    def quitting(self):
        """Senada is quitting: the main window closes for real instead of going to the tray."""
        return self._quitting

    @Slot()
    def quit(self):
        """Quit Senada (Ctrl+Q, the tray menu, an update), also while closing goes to the tray."""
        self._quitting = True
        QCoreApplication.quit()

    # ---- mini player ("dynamic island") -------------------------------------------

    @Slot(QObject)
    def minimize(self, window):
        """Minimize, keeping a maximized window maximized for when it comes back. QWindow's
        showMinimized() drops the maximized state, so the taskbar or Alt+Tab brought it back
        at its normal size."""
        if isinstance(window, QWindow):
            kept = window.windowStates() & Qt.WindowState.WindowMaximized
            window.setWindowStates(kept | Qt.WindowState.WindowMinimized)

    @Slot()
    def prepareMiniPlayer(self):
        """Window rules that float the mini player at the top of the screen (Hyprland)."""
        island.prepare()

    @Slot(QObject, int, int, int, int)
    def setInputArea(self, window, x, y, w, h):
        """Only this rectangle of a see-through window takes clicks, so the empty space
        around the mini player's pill does not block what is underneath."""
        if isinstance(window, QWindow):
            window.setMask(QRegion(x, y, max(1, w), max(1, h)))

    # ---- settings ---------------------------------------------------------

    def _setting(key):
        def getter(self):
            return self.settings[key]

        def setter(self, value):
            self.settings[key] = value
            self.changed.emit()
        return getter, setter

    deviceName = Property(str, *_setting("device_name"), notify=changed)
    accentColor = Property(str, *_setting("accent"), notify=changed)
    accentStrength = Property(str, *_setting("accent_strength"), notify=changed)
    visualizerEnabled = Property(bool, *_setting("visualizer"), notify=changed)
    visualizerStyle = Property(str, *_setting("visualizer_style"), notify=changed)
    def _get_immersive_style(self):
        style = self.settings["immersive_style"]
        return style if style in IMMERSIVE_STYLES else IMMERSIVE_STYLES[0]  # e.g. a style that was removed

    def _set_immersive_style(self, value):
        self.settings["immersive_style"] = value if value in IMMERSIVE_STYLES else IMMERSIVE_STYLES[0]
        self.changed.emit()

    immersiveStyle = Property(str, _get_immersive_style, _set_immersive_style, notify=changed)
    seekStyle = Property(str, *_setting("seek_style"), notify=changed)
    miniPlayer = Property(bool, *_setting("mini_player"), notify=changed)
    trayIcon = Property(bool, *_setting("tray"), notify=changed)
    closeToTray = Property(bool, *_setting("close_to_tray"), notify=changed)
    trayHintShown = Property(bool, *_setting("tray_hint_shown"), notify=changed)

    def _get_island_style(self):
        style = self.settings["island_style"]
        return style if style in ISLAND_STYLES else ISLAND_STYLES[0]

    def _set_island_style(self, value):
        self.settings["island_style"] = value if value in ISLAND_STYLES else ISLAND_STYLES[0]
        self.changed.emit()

    islandStyle = Property(str, _get_island_style, _set_island_style, notify=changed)

    def _get_island_dock(self):
        try:
            seconds = int(self.settings["island_dock"])
        except (TypeError, ValueError):
            return ISLAND_DOCK_DEFAULT
        return 0 if seconds <= 0 else max(ISLAND_DOCK_MIN, min(ISLAND_DOCK_MAX, seconds))

    def _set_island_dock(self, value):
        seconds = int(value)
        self.settings["island_dock"] = 0 if seconds <= 0 else max(ISLAND_DOCK_MIN, min(ISLAND_DOCK_MAX, seconds))
        self.changed.emit()

    # seconds before the mini player tucks into the top edge of the screen; 0: never
    islandDock = Property(int, _get_island_dock, _set_island_dock, notify=changed)
    def _choice(key):
        """A setting that is one of CHOICES[key] (anything else reads as the first)."""
        choices = CHOICES[key]

        def getter(self):
            value = self.settings[key]
            return value if value in choices else choices[0]

        def setter(self, value):
            self.settings[key] = value if value in choices else choices[0]
            self.changed.emit()
        return getter, setter

    lyricsSize = Property(str, *_choice("lyrics_size"), notify=changed)
    lyricsFont = Property(str, *_choice("lyrics_font"), notify=changed)
    lyricsAlign = Property(str, *_choice("lyrics_align"), notify=changed)
    lyricsHighlight = Property(str, *_choice("lyrics_highlight"), notify=changed)
    playerBarStyle = Property(str, *_choice("player_bar"), notify=changed)
    del _setting, _choice
