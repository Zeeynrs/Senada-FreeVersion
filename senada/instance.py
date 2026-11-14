"""One Senada at a time.

With the window closed to the tray Senada keeps running, and opening it again from the Start
menu or a launcher would start a second one playing over the first. The first Senada listens
on a local socket (a named pipe on Windows); a second one finds it there, asks it to show its
window, and exits.
"""

import getpass
import re

from PySide6.QtCore import QObject, Signal
from PySide6.QtNetwork import QLocalServer, QLocalSocket

CONNECT_MS = 500


def server_name() -> str:
    try:
        user = getpass.getuser()
    except OSError:
        user = ""
    return "senada-" + (re.sub(r"[^A-Za-z0-9_-]", "_", user) or "user")


def ask_running_to_show(name: str | None = None) -> bool:
    """True when another Senada is running (and was asked to show its window)."""
    sock = QLocalSocket()
    sock.connectToServer(name or server_name())
    if not sock.waitForConnected(CONNECT_MS):
        return False
    sock.write(b"show\n")
    sock.waitForBytesWritten(CONNECT_MS)
    sock.disconnectFromServer()
    return True


class Instance(QObject):
    """Listens for a second Senada; showRequested when one starts."""
    showRequested = Signal()

    def __init__(self, name: str | None = None, parent=None):
        super().__init__(parent)
        self.name = name or server_name()
        self.server = QLocalServer(self)
        self.server.setSocketOptions(QLocalServer.SocketOption.UserAccessOption)
        self.server.newConnection.connect(self._on_connection)
        if not self.server.listen(self.name):
            QLocalServer.removeServer(self.name)  # left behind by a Senada that crashed (Unix)
            self.server.listen(self.name)

    def _on_connection(self):
        while self.server.hasPendingConnections():
            sock = self.server.nextPendingConnection()
            sock.readyRead.connect(lambda s=sock: self._on_read(s))
            sock.disconnected.connect(sock.deleteLater)
            if sock.bytesAvailable():  # already here before readyRead was connected
                self._on_read(sock)

    def _on_read(self, sock):
        if b"show" in bytes(sock.readAll()):
            self.showRequested.emit()

    def close(self):
        """Stop listening (before a restart starts the new Senada)."""
        self.server.close()
