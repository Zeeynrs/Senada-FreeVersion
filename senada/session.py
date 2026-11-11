"""User-facing settings and small desktop helpers exposed to QML.

Senada needs no account: there is no login state here any more.
"""

import getpass
import os
import pwd

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication

from .config import LIBRARY_FILE


def _os_user_name() -> str:
    try:
        gecos = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
        if gecos:
            return gecos
    except (KeyError, OSError):
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
