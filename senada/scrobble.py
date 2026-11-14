"""Scrobbling: the songs you listen to, added to your Last.fm or Libre.fm profile.

Your own account on that service (Senada still has none): Settings → Scrobbling opens the
service's page in the browser to allow Senada, and Senada keeps the session it then gets.
A song is scrobbled once heard for half its length or 4 minutes (the services' rule), and
"now playing" is sent when it starts. Scrobbles that could not be sent (no internet) wait in
scrobbles.json and go with the next one.

Last.fm only answers apps with a key of their own: set LASTFM_API_KEY and LASTFM_API_SECRET
(see config.py). Libre.fm takes any key, so it always works.
"""

import hashlib
import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices

from . import net
from .config import CONFIG_DIR, LASTFM_API_KEY, LASTFM_API_SECRET, read_json, write_private
from .i18n import tr

logger = logging.getLogger("senada.scrobble")

QUEUE_FILE = CONFIG_DIR / "scrobbles.json"
QUEUE_LIMIT = 1000
BATCH = 50                 # scrobbles per request (the API's limit)
AUTH_POLL_MS = 3000        # while the browser page is open: is it allowed yet?
AUTH_TIMEOUT_S = 180
LIBREFM_KEY = "senada" + "0" * 26     # Libre.fm takes any key and secret
LIBREFM_SECRET = "senada" + "1" * 26

SERVICES = {
    "lastfm": {"name": "Last.fm", "api": "https://ws.audioscrobbler.com/2.0/",
               "auth": "https://www.last.fm/api/auth/", "key": LASTFM_API_KEY, "secret": LASTFM_API_SECRET},
    "librefm": {"name": "Libre.fm", "api": "https://libre.fm/2.0/",
                "auth": "https://libre.fm/api/auth/", "key": LIBREFM_KEY, "secret": LIBREFM_SECRET},
}


class ScrobbleError(Exception):
    pass


def should_scrobble(listened_ms: int, duration_ms: int) -> bool:
    """Last.fm's rule: longer than 30 s, and heard for half of it or 4 minutes."""
    if duration_ms and duration_ms <= 30_000:
        return False
    return listened_ms >= min(240_000, (duration_ms or 0) / 2) and listened_ms >= 30_000


def sign(params: dict, secret: str) -> str:
    raw = "".join(k + str(params[k]) for k in sorted(params) if k not in ("format", "callback")) + secret
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


def call(service: str, method: str, params: dict, session: str = "") -> dict:
    """A signed POST to the service's API; raises ScrobbleError with its message."""
    svc = SERVICES[service]
    data = {"method": method, "api_key": svc["key"], **{k: str(v) for k, v in params.items() if v not in (None, "")}}
    if session:
        data["sk"] = session
    data["api_sig"] = sign(data, svc["secret"])
    data["format"] = "json"
    req = urllib.request.Request(svc["api"], data=urllib.parse.urlencode(data).encode(),
                                 headers={"User-Agent": "Senada (desktop music player)"})
    try:
        with net.urlopen(req, timeout=15) as resp:
            out = json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            out = json.loads(e.read() or b"{}")
        except ValueError:
            raise ScrobbleError(f"HTTP {e.code}") from e
    if isinstance(out, dict) and out.get("error"):
        raise ScrobbleError(str(out.get("message") or out["error"]))
    return out if isinstance(out, dict) else {}


def track_params(track: dict, timestamp: float | None = None, index: int | None = None) -> dict:
    sfx = f"[{index}]" if index is not None else ""
    artist = (track.get("artists") or "").split(",")[0].strip()
    params = {f"artist{sfx}": artist, f"track{sfx}": track.get("name", ""), f"album{sfx}": track.get("album", "")}
    if track.get("durationMs"):
        params[f"duration{sfx}"] = int(track["durationMs"] / 1000)
    if timestamp is not None:
        params[f"timestamp{sfx}"] = int(timestamp)
    return params


class Scrobbler(QObject):
    changed = Signal()
    toast = Signal(str)
    _authorized = Signal(str, str, str)   # service, user, session (from a worker thread)

    def __init__(self, tracker, settings, worker, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.worker = worker
        self._token = ""
        self._auth_service = ""
        self._auth_until = 0.0
        self._sending = False
        self._queue = read_json(QUEUE_FILE).get("scrobbles") or []
        self._poll = QTimer(self, interval=AUTH_POLL_MS, timeout=self._check_auth)
        self._authorized.connect(self._on_authorized)
        tracker.started.connect(self._on_started)
        tracker.finished.connect(self._on_finished)
        if self.connected and self._queue:
            QTimer.singleShot(5000, self._send_queue)

    # ---- state for QML ------------------------------------------------------------------

    @Property(str, notify=changed)
    def service(self):
        return self.settings["scrobble_service"] or ""

    @Property(str, notify=changed)
    def serviceName(self):
        return SERVICES.get(self.service, {}).get("name", "")

    @Property(str, notify=changed)
    def user(self):
        return self.settings["scrobble_user"] or ""

    @Property(bool, notify=changed)
    def connected(self):
        return bool(self.service in SERVICES and self.settings["scrobble_session"])

    @Property(bool, notify=changed)
    def connecting(self):
        return bool(self._token)

    @Property(bool, constant=True)
    def lastfmAvailable(self):
        return bool(LASTFM_API_KEY and LASTFM_API_SECRET)

    @Property(int, notify=changed)
    def waiting(self):
        """Scrobbles not sent yet."""
        return len(self._queue)

    # ---- connecting ------------------------------------------------------------------------

    @Slot(str)
    def connectTo(self, service):
        """Open the service's page to allow Senada; the session is picked up when it is allowed."""
        if service not in SERVICES or (service == "lastfm" and not self.lastfmAvailable):
            return
        self._auth_service = service

        def got(token):
            self._token = token
            self._auth_until = time.time() + AUTH_TIMEOUT_S
            svc = SERVICES[service]
            QDesktopServices.openUrl(QUrl(svc["auth"] + "?" + urllib.parse.urlencode(
                {"api_key": svc["key"], "token": token})))
            self._poll.start()
            self.changed.emit()

        self.worker.run(lambda: call(service, "auth.getToken", {})["token"], got,
                        lambda e: self.toast.emit(tr("Could not reach {service}: {error}",
                                                     service=SERVICES[service]["name"], error=e)))

    @Slot()
    def cancelConnect(self):
        self._poll.stop()
        self._token = ""
        self.changed.emit()

    def _check_auth(self):
        if not self._token or time.time() > self._auth_until:
            self.cancelConnect()
            return
        token, service = self._token, self._auth_service

        def ask():
            try:
                s = call(service, "auth.getSession", {"token": token}).get("session") or {}
            except ScrobbleError:
                return  # not allowed yet
            if s.get("key"):
                self._authorized.emit(service, s.get("name", ""), s["key"])

        self.worker.run(ask, None, lambda e: None)

    def _on_authorized(self, service, user, session):
        if not self._token:
            return
        self._poll.stop()
        self._token = ""
        self.settings["scrobble_service"] = service
        self.settings["scrobble_user"] = user
        self.settings["scrobble_session"] = session
        self.changed.emit()
        self.toast.emit(tr("Scrobbling to {service} as {user}", service=SERVICES[service]["name"], user=user))
        self._send_queue()

    @Slot()
    def disconnect(self):
        for key in ("scrobble_service", "scrobble_user", "scrobble_session"):
            self.settings[key] = ""
        self.changed.emit()

    # ---- scrobbling ------------------------------------------------------------------------

    def _on_started(self, track):
        if not self.connected or not track.get("name"):
            return
        service, session = self.service, self.settings["scrobble_session"]
        self.worker.run(lambda: call(service, "track.updateNowPlaying", track_params(track), session),
                        None, lambda e: logger.info("now playing not sent: %s", e))

    def _on_finished(self, track, listened_ms, started_at):
        if not self.connected or not track.get("name") or not track.get("artists"):
            return
        if not should_scrobble(listened_ms, int(track.get("durationMs") or 0)):
            return
        keep = {k: track.get(k, "") for k in ("name", "artists", "album", "durationMs")}
        self._queue.append({**keep, "timestamp": int(started_at)})
        self._queue = self._queue[-QUEUE_LIMIT:]
        self._save_queue()
        self._send_queue()

    def _save_queue(self):
        try:
            write_private(QUEUE_FILE, {"scrobbles": self._queue})
        except OSError as e:
            logger.warning("scrobble queue not saved: %s", e)

    def _send_queue(self):
        if self._sending or not self.connected or not self._queue:
            return
        batch = self._queue[:BATCH]
        service, session = self.service, self.settings["scrobble_session"]
        params = {}
        for i, s in enumerate(batch):
            params.update(track_params(s, s["timestamp"], i))
        self._sending = True

        def sent(_):
            self._sending = False
            self._queue = self._queue[len(batch):]
            self._save_queue()
            self.changed.emit()
            if self._queue:
                self._send_queue()

        def failed(e):
            self._sending = False
            self.changed.emit()
            logger.info("scrobbles kept for later: %s", e)
            if isinstance(e, ScrobbleError) and "session" in str(e).lower():
                self.disconnect()  # the access was taken back on the website
                self.toast.emit(tr("{service} no longer allows Senada: connect again in Settings",
                                   service=SERVICES[service]["name"]))

        self.worker.run(lambda: call(service, "track.scrobble", params, session), sent, failed)
