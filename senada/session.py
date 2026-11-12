"""User-facing settings and small desktop helpers exposed to QML.

Senada needs no account: there is no login state here any more.
"""

import getpass
import os

from PySide6.QtCore import Property, QObject, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication

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
    toast = Signal(str)

    def __init__(self, settings, worker, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.worker = worker
        worker.error.connect(self.toast)
        self._apply_theme()

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

    @Property(str, notify=changed)
    def themeMode(self):
        mode = self.settings["theme"]
        return mode if mode in self.THEMES else "system"

    @themeMode.setter
    def themeMode(self, value):
        if value in self.THEMES and value != self.settings["theme"]:
            self.settings["theme"] = value
            self._apply_theme()
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
        self.toast.emit("Disalin ke clipboard")

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
    visualizerEnabled = Property(bool, *_setting("visualizer"), notify=changed)
    visualizerStyle = Property(str, *_setting("visualizer_style"), notify=changed)
    del _setting
