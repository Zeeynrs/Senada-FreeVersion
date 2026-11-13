"""User-facing settings and small desktop helpers exposed to QML.

Senada needs no account: there is no login state here any more.
"""

import getpass
import os

from PySide6.QtCore import Property, QObject, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication

from . import i18n
from .config import LIBRARY_FILE


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


class Session(QObject):
    changed = Signal()
    languageChanged = Signal()
    toast = Signal(str)

    def __init__(self, settings, worker, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.worker = worker
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
    del _setting
