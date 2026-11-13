"""Log files, so a problem on someone's computer can be looked into afterwards.

senada.log holds Senada's own messages (kept small: it rolls over at 1 MB). The Windows build
has no console, so anything printed to stderr there (Python tracebacks, QML warnings) went
nowhere; it goes into senada.log too. mpv writes its own mpv.log next to it (see engine.py).
"""

import logging
import logging.handlers
import platform
import sys

from . import __version__
from .config import FROZEN, LOG_DIR

LOG_FILE = LOG_DIR / "senada.log"
MPV_LOG_FILE = LOG_DIR / "mpv.log"


class _StderrToLog:
    """Stands in for a missing sys.stderr (windowed build): lines go to the log."""

    def __init__(self):
        self._log = logging.getLogger("senada.stderr")
        self._buf = ""

    def write(self, text):
        self._buf += str(text)
        *lines, self._buf = self._buf.split("\n")
        for line in lines:
            if line.strip():
                self._log.warning(line.rstrip())
        return len(text)

    def flush(self):
        pass

    def isatty(self):
        return False


def setup() -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        handler = logging.handlers.RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=1,
                                                       encoding="utf-8")
    except OSError:
        return  # no log then, Senada works the same
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    log = logging.getLogger("senada")
    log.setLevel(logging.INFO)
    log.addHandler(handler)
    if sys.stderr is None:
        sys.stderr = _StderrToLog()
    log.info("Senada %s (%s) on %s, Python %s", __version__, "installed" if FROZEN else "source",
             platform.platform(), platform.python_version())
