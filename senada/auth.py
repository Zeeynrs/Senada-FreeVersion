"""Spotify OAuth (Authorization Code + PKCE) without a client secret."""

import base64
import hashlib
import json
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

from .config import REDIRECT_PORT, REDIRECT_URI, TOKENS_FILE, read_json, write_private

AUTHORIZE_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
SCOPES = " ".join([
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "user-read-recently-played",
    "user-top-read",
    "user-read-private",
    "user-library-read",
    "user-library-modify",
    "playlist-read-private",
    "playlist-read-collaborative",
])

DONE_PAGE = """<!doctype html><meta charset=utf-8><title>Senada</title>
<body style="background:#111;color:#eee;font-family:sans-serif;display:grid;place-items:center;height:100vh;margin:0">
<div style="text-align:center"><h1>{title}</h1><p>{body}</p></div></body>"""


class AuthError(Exception):
    pass


def _post_token(form: dict) -> dict:
    data = urllib.parse.urlencode(form).encode()
    req = urllib.request.Request(TOKEN_URL, data=data, headers={
        "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        try:
            detail = json.loads(e.read()).get("error_description", "")
        except ValueError:
            detail = ""
        raise AuthError(f"Spotify menolak token ({e.code}) {detail}".strip()) from e
    except urllib.error.URLError as e:
        raise AuthError(f"Tidak bisa menghubungi Spotify: {e.reason}") from e


def begin_login(client_id: str):
    """Start the local redirect server and return (authorize_url, wait_fn).

    wait_fn() blocks until the browser comes back, then returns token data.
    """
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result = {}
    got = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path != "/login":
                self.send_error(404)
                return
            q = urllib.parse.parse_qs(url.query)
            if q.get("state", [""])[0] != state:
                result["error"] = "state tidak cocok"
            elif "error" in q:
                result["error"] = q["error"][0]
            else:
                result["code"] = q.get("code", [""])[0]
            ok = "code" in result
            page = DONE_PAGE.format(
                title="Berhasil masuk 🎵" if ok else "Gagal masuk",
                body="Kamu bisa menutup tab ini dan kembali ke Nada." if ok else result.get("error", ""))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(page.encode())
            got.set()

        def log_message(self, *args):
            pass

    try:
        server = HTTPServer(("127.0.0.1", REDIRECT_PORT), Handler)
    except OSError as e:
        raise AuthError(f"Port {REDIRECT_PORT} sedang dipakai aplikasi lain") from e
    server.timeout = 0.5

    url = AUTHORIZE_URL + "?" + urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
        "scope": SCOPES,
        "state": state,
    })

    def wait():
        deadline = time.monotonic() + 300
        try:
            while not got.is_set() and time.monotonic() < deadline:
                server.handle_request()
        finally:
            server.server_close()
        if "code" not in result:
            raise AuthError(result.get("error", "Waktu login habis"))
        return _post_token({
            "grant_type": "authorization_code",
            "code": result["code"],
            "redirect_uri": REDIRECT_URI,
            "client_id": client_id,
            "code_verifier": verifier,
        })

    return url, wait


def get_token_from_sp_dc(sp_dc: str) -> dict:
    """Retrieve a Spotify Web Player access token using the sp_dc session cookie.
    Does NOT require a Spotify Developer Application or Spotify Premium subscription.
    """
    sp_dc = sp_dc.strip()
    if not sp_dc:
        raise AuthError("Cookie sp_dc tidak boleh kosong.")

    url = "https://open.spotify.com/get_access_token?reason=transport&productType=web_player"
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Cookie": f"sp_dc={sp_dc}",
        "App-Platform": "WebPlayer",
        "Referer": "https://open.spotify.com/",
    })
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if not data.get("accessToken") or data.get("isAnonymous"):
                raise AuthError("Cookie sp_dc tidak valid atau sesi login di browser sudah berakhir.")
            exp_ms = data.get("accessTokenExpirationTimestampMs") or ((time.time() + 3600) * 1000)
            return {
                "access_token": data["accessToken"],
                "expires_at": (exp_ms / 1000.0) - 60,
                "sp_dc": sp_dc,
                "client_id": data.get("clientId", "sp_dc_client"),
            }
    except urllib.error.HTTPError as e:
        raise AuthError(f"Gagal memverifikasi cookie sp_dc ({e.code}). Pastikan nilainya benar.") from e
    except Exception as e:
        raise AuthError(f"Tidak dapat menghubungi Spotify: {e}") from e


class TokenStore:
    """Holds the access token and refreshes it when it expires. Thread-safe."""

    def __init__(self):
        self._lock = threading.Lock()
        self._data = read_json(TOKENS_FILE)
        # Migrasi otomatis dari Nada jika Senada belum memiliki token aktif
        if not self.has_tokens:
            nada_tokens = TOKENS_FILE.parent.parent / "nada" / "tokens.json"
            if nada_tokens.exists():
                try:
                    imported = read_json(nada_tokens)
                    if imported.get("refresh_token") and imported.get("client_id"):
                        self._data = imported
                        write_private(TOKENS_FILE, self._data)
                except Exception:
                    pass

    @property
    def has_tokens(self) -> bool:
        return bool(self._data.get("access_token") and (self._data.get("refresh_token") or self._data.get("sp_dc")))

    def save(self, client_id: str, token: dict) -> None:
        with self._lock:
            self._data = {
                "client_id": client_id,
                "access_token": token["access_token"],
                "refresh_token": token.get("refresh_token") or self._data.get("refresh_token"),
                "expires_at": time.time() + token.get("expires_in", 3600) - 60,
            }
            write_private(TOKENS_FILE, self._data)

    def save_cookie(self, token_info: dict) -> None:
        with self._lock:
            self._data = {
                "client_id": token_info.get("client_id", "sp_dc_client"),
                "access_token": token_info["access_token"],
                "sp_dc": token_info["sp_dc"],
                "expires_at": token_info.get("expires_at", time.time() + 3500),
            }
            write_private(TOKENS_FILE, self._data)

    def clear(self) -> None:
        with self._lock:
            self._data = {}
            TOKENS_FILE.unlink(missing_ok=True)

    def access_token(self, force_refresh: bool = False) -> str:
        with self._lock:
            if not self.has_tokens:
                raise AuthError("Belum login")
            if force_refresh or time.time() >= self._data.get("expires_at", 0):
                if self._data.get("sp_dc"):
                    info = get_token_from_sp_dc(self._data["sp_dc"])
                    self._data.update(info)
                    write_private(TOKENS_FILE, self._data)
                elif self._data.get("refresh_token"):
                    client_id = self._data["client_id"]
                    token = _post_token({
                        "grant_type": "refresh_token",
                        "refresh_token": self._data["refresh_token"],
                        "client_id": client_id,
                    })
                    self._data.update({
                        "access_token": token["access_token"],
                        "refresh_token": token.get("refresh_token") or self._data["refresh_token"],
                        "expires_at": time.time() + token.get("expires_in", 3600) - 60,
                    })
                    write_private(TOKENS_FILE, self._data)
            return self._data["access_token"]
