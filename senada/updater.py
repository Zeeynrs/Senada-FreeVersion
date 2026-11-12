"""GitHub update checker and one-click self-updater.

A git checkout follows the commits on GitHub (fetch + fast-forward). The Windows installer
build follows GitHub Releases instead: it downloads the newer Senada-Setup-<version>.exe,
runs it silently and quits; the installer replaces the files and starts Senada again.
"""

import hashlib
import json
import re
import shutil
import subprocess
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from . import __version__
from .config import CACHE_DIR, FROZEN, IS_WINDOWS, NO_WINDOW, ROOT

REPO = "Zeeynrs/Senada-FreeVersion"
RELEASES_API = f"https://api.github.com/repos/{REPO}/releases/latest"
NOT_GIT_HINT = "Senada dipasang lewat paket sistem. Gunakan manajer paket atau ./install.sh untuk memperbarui."
CHECK_INTERVAL_MS = 180_000  # 3 minutes (git checkout)
RELEASE_CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000  # 6 hours (installer build; GitHub API allows 60/hour)
UPDATES_DIR = CACHE_DIR / "updates"
SETUP_ASSET = re.compile(r"Senada-Setup-[\w.\-]+\.exe", re.I)


def version_tuple(version: str) -> tuple[int, ...]:
    """'v1.2.10' -> (1, 2, 10); anything that isn't a number is ignored."""
    return tuple(int(n) for n in re.findall(r"\d+", version)[:4])


def pick_setup_asset(assets: list[dict]) -> dict | None:
    return next((a for a in assets if SETUP_ASSET.fullmatch(a.get("name", ""))), None)


def _http(url: str, timeout: int = 20):
    req = urllib.request.Request(url, headers={"User-Agent": f"Senada/{__version__}",
                                               "Accept": "application/vnd.github+json"})
    return urllib.request.urlopen(req, timeout=timeout)


def _latest_release() -> dict:
    try:
        with _http(RELEASES_API) as res:
            data = json.load(res)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        data = {}  # nothing released yet

    tag = data.get("tag_name") or ""
    return {
        "tag": tag,
        "name": data.get("name") or tag,
        "notes": (data.get("body") or "").strip(),
        "asset": pick_setup_asset(data.get("assets") or []),
    }


def _launch_installer(path: Path) -> None:
    """Start the installer detached so it outlives Senada; /RELAUNCH=1 makes it reopen Senada."""
    flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP if IS_WINDOWS else 0
    subprocess.Popen([str(path), "/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS",
                      "/RELAUNCH=1"], close_fds=True, creationflags=flags)


def _git(*args: str, timeout: int = 15) -> str:
    res = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        creationflags=NO_WINDOW,
    )
    if res.returncode != 0:
        err = (res.stderr or res.stdout or "").strip()
        raise RuntimeError(err or f"git {' '.join(args)} gagal")
    return res.stdout.strip()


def _send_desktop_notification(title: str, body: str) -> None:
    if not shutil.which("notify-send"):
        return
    try:
        subprocess.Popen(
            ["notify-send", "-a", "Senada", "-i", "senada", title, body],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


class Updater(QObject):
    changed = Signal()
    toast = Signal(str)
    restartRequested = Signal()
    quitRequested = Signal()  # the installer takes over and starts Senada again itself
    _progressFromThread = Signal(int)

    def __init__(self, worker, parent=None, release_mode: bool | None = None):
        super().__init__(parent)
        self.worker = worker
        # installer builds update from GitHub Releases, git checkouts from commits
        self._release_mode = (FROZEN and IS_WINDOWS) if release_mode is None else release_mode
        self._release: dict | None = None
        self._progress = -1  # download progress in %, -1 when unknown
        self._progressFromThread.connect(self._set_progress)
        self.launch_installer = _launch_installer  # replaced in tests
        self._checking = False
        self._updating = False
        self._current_hash = ""
        self._current_msg = ""
        self._remote_hash = ""
        self._remote_msg = ""
        self._commits_behind = 0
        self._changelog = ""
        self._last_checked = "Belum diperiksa"
        self._notified_hash = ""
        self._dismissed_hash = ""

        self._is_git_repo = not self._release_mode and (ROOT / ".git").exists()
        self._read_local_head()

        self._timer = QTimer(self)
        self._timer.setInterval(RELEASE_CHECK_INTERVAL_MS if self._release_mode else CHECK_INTERVAL_MS)
        self._timer.timeout.connect(lambda: self.check(True))
        if self._is_git_repo or self._release_mode:
            self._timer.start()
            QTimer.singleShot(2500, lambda: self.check(True))
        if self._release_mode:  # installers downloaded for earlier updates are no longer needed
            shutil.rmtree(UPDATES_DIR, ignore_errors=True)

    def _read_local_head(self):
        if self._release_mode:
            self._current_hash = f"v{__version__}"
            self._current_msg = "Dipasang lewat installer Windows"
            return
        if not self._is_git_repo:
            self._current_hash = "paket sistem"
            self._current_msg = "Dipasang lewat paket"
            return
        try:
            self._current_hash = _git("rev-parse", "--short", "HEAD", timeout=3)
            self._current_msg = _git("log", "-1", "--format=%s", "HEAD", timeout=3)
        except Exception:
            self._current_hash = "unknown"
            self._current_msg = ""

    @Property(bool, notify=changed)
    def checking(self):
        return self._checking

    @Property(bool, notify=changed)
    def updating(self):
        return self._updating

    @Property(bool, notify=changed)
    def updateAvailable(self):
        return self._commits_behind > 0

    @Property(bool, notify=changed)
    def bannerVisible(self):
        return self._commits_behind > 0 and self._remote_hash != self._dismissed_hash

    @Property(int, notify=changed)
    def commitsBehind(self):
        return self._commits_behind

    @Property(str, notify=changed)
    def currentHash(self):
        return self._current_hash

    @Property(str, notify=changed)
    def currentMessage(self):
        return self._current_msg

    @Property(str, notify=changed)
    def remoteHash(self):
        return self._remote_hash

    @Property(str, notify=changed)
    def remoteMessage(self):
        return self._remote_msg

    @Property(str, notify=changed)
    def changelog(self):
        return self._changelog

    @Property(str, notify=changed)
    def lastChecked(self):
        return self._last_checked

    @Property(bool, constant=True)
    def releaseMode(self):
        return self._release_mode

    @Property(int, notify=changed)
    def progress(self):
        return self._progress

    @Property(str, notify=changed)
    def bannerTitle(self):
        if self._release_mode:
            return f"Senada {self._remote_hash} tersedia"
        return f"Update GitHub tersedia ({self._commits_behind} commit)"

    @Property(str, notify=changed)
    def badgeText(self):
        if self._updating:
            return self.statusText if self._release_mode else "Memperbarui…"
        if self._release_mode:
            return f"Perbarui ke {self._remote_hash}"
        return f"Perbarui ({self._commits_behind})"

    @Property(str, notify=changed)
    def currentLabel(self):
        if self._release_mode:
            return f"Versi saat ini: {self._current_hash}"
        return "Commit saat ini: " + self._current_hash + (f" — {self._current_msg}" if self._current_msg else "")

    @Slot(int)
    def _set_progress(self, pct: int):
        if pct != self._progress:
            self._progress = pct
            self.changed.emit()

    @Property(str, notify=changed)
    def statusText(self):
        if self._release_mode:
            if self._updating:
                return f"Mengunduh pembaruan… {self._progress}%" if self._progress >= 0 else "Mengunduh pembaruan…"
            if self._checking:
                return "Memeriksa rilis terbaru di GitHub…"
            if self._commits_behind > 0:
                return f"Versi baru tersedia: {self._remote_hash}"
            return f"Sudah versi terbaru ({self._current_hash})"
        if self._updating:
            return "Mengunduh & memasang pembaruan…"
        if self._checking:
            return "Memeriksa commit terbaru di GitHub…"
        if self._commits_behind > 0:
            return f"Tersedia {self._commits_behind} commit baru ({self._remote_hash})"
        return f"Sudah versi terbaru ({self._current_hash})"

    @Slot()
    def dismissBanner(self):
        self._dismissed_hash = self._remote_hash
        self.changed.emit()

    @Slot()
    @Slot(bool)
    def check(self, silent: bool = False):
        if self._release_mode:
            self._check_release(silent)
            return
        if not self._is_git_repo:
            if not silent:
                self.toast.emit(NOT_GIT_HINT)
            return
        if self._checking or self._updating:
            return
        self._checking = True
        self.changed.emit()

        def job():
            branch = _git("rev-parse", "--abbrev-ref", "HEAD", timeout=5) or "main"
            if branch == "HEAD":
                branch = "main"
            _git("fetch", "origin", branch, "--quiet", timeout=20)
            local_hash = _git("rev-parse", "--short", "HEAD", timeout=5)
            local_msg = _git("log", "-1", "--format=%s", "HEAD", timeout=5)
            remote_ref = f"origin/{branch}"
            remote_hash = _git("rev-parse", "--short", remote_ref, timeout=5)
            remote_msg = _git("log", "-1", "--format=%s", remote_ref, timeout=5)
            behind_str = _git("rev-list", "--count", f"HEAD..{remote_ref}", timeout=5)
            behind = int(behind_str) if behind_str.isdigit() else 0
            log_lines = ""
            if behind > 0:
                log_lines = _git("log", "--format=• %h — %s (%cr)", f"HEAD..{remote_ref}", timeout=5)
            return {
                "local_hash": local_hash,
                "local_msg": local_msg,
                "remote_hash": remote_hash,
                "remote_msg": remote_msg,
                "behind": behind,
                "changelog": log_lines,
            }

        def on_ok(info):
            self._checking = False
            self._current_hash = info["local_hash"]
            self._current_msg = info["local_msg"]
            self._remote_hash = info["remote_hash"]
            self._remote_msg = info["remote_msg"]
            self._commits_behind = info["behind"]
            self._changelog = info["changelog"]
            self._last_checked = datetime.now().strftime("%H:%M")
            self.changed.emit()

            if self._commits_behind > 0:
                if self._remote_hash != self._notified_hash:
                    self._notified_hash = self._remote_hash
                    msg = f"Update GitHub tersedia ({self._commits_behind} commit): {self._remote_msg}"
                    self.toast.emit(msg)
                    _send_desktop_notification(
                        "Pembaruan Senada Tersedia",
                        f"{self._remote_msg}\n({self._commits_behind} commit baru di GitHub)",
                    )
                elif not silent:
                    self.toast.emit(f"Tersedia {self._commits_behind} commit baru: {self._remote_msg}")
            elif not silent:
                self.toast.emit("Senada sudah berada di commit terbaru")

        def on_err(err):
            self._checking = False
            self.changed.emit()
            if not silent:
                self.toast.emit(f"Gagal memeriksa update: {err}")

        self.worker.run(job, on_ok, on_err)

    @Slot()
    def applyUpdate(self):
        if self._release_mode:
            self._apply_release()
            return
        if not self._is_git_repo:
            self.toast.emit(NOT_GIT_HINT)
            return
        if self._updating:
            return
        self._updating = True
        self.changed.emit()
        self.toast.emit("Mengunduh commit terbaru dari GitHub…")

        def job():
            branch = _git("rev-parse", "--abbrev-ref", "HEAD", timeout=5) or "main"
            if branch == "HEAD":
                branch = "main"
            _git("fetch", "origin", branch, "--quiet", timeout=25)
            dirty = _git("status", "--porcelain", timeout=5)
            stashed = False
            if dirty:
                _git("stash", "push", "--include-untracked", "-m", "senada-auto-update", timeout=10)
                stashed = True
            try:
                _git("merge", "--ff-only", f"origin/{branch}", timeout=20)
            except Exception:
                _git("reset", "--hard", f"origin/{branch}", timeout=20)
            if stashed:
                try:
                    _git("stash", "pop", timeout=10)
                except Exception:
                    pass

            # Clear QML bytecode cache so updated QML files load fresh
            qmlcache = CACHE_DIR / "Senada" / "qmlcache"
            if qmlcache.exists():
                shutil.rmtree(qmlcache, ignore_errors=True)

            # Keep launcher & icon up to date
            bin_dir = Path.home() / ".local" / "bin"
            if not IS_WINDOWS and bin_dir.exists():
                launcher = bin_dir / "senada"
                venv_py = ROOT / ".venv" / "bin" / "python3"
                if venv_py.exists():
                    py_cmd = f'"{venv_py}"'
                else:
                    py_cmd = "python3 -I"
                launcher.write_text(
                    '#!/bin/sh\n'
                    'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"\n'
                    f'exec {py_cmd} "{ROOT / "run.py"}" "$@"\n'
                )
                launcher.chmod(0o755)
            icon_src = ROOT / "data" / "senada.svg"
            icon_dst = Path.home() / ".local" / "share" / "icons" / "hicolor" / "scalable" / "apps" / "senada.svg"
            if icon_src.exists() and icon_dst.parent.exists():
                shutil.copy2(icon_src, icon_dst)

            new_hash = _git("rev-parse", "--short", "HEAD", timeout=5)
            new_msg = _git("log", "-1", "--format=%s", "HEAD", timeout=5)
            return {"hash": new_hash, "msg": new_msg}

        def on_ok(res):
            self._updating = False
            self._current_hash = res["hash"]
            self._current_msg = res["msg"]
            self._remote_hash = res["hash"]
            self._remote_msg = res["msg"]
            self._commits_behind = 0
            self._changelog = ""
            self.changed.emit()
            self.toast.emit(f"Berhasil diperbarui ke {res['hash']}! Memulai ulang Senada…")
            _send_desktop_notification(
                "Senada Berhasil Diperbarui",
                f"Berjalan di commit {res['hash']}: {res['msg']}",
            )
            QTimer.singleShot(900, self.restartRequested.emit)

        def on_err(err):
            self._updating = False
            self.changed.emit()
            self.toast.emit(f"Gagal memperbarui: {err}")

        self.worker.run(job, on_ok, on_err)

    # ---- installer builds: GitHub Releases ----------------------------------------

    def _check_release(self, silent: bool):
        if self._checking or self._updating:
            return
        self._checking = True
        self.changed.emit()

        def on_ok(rel):
            self._checking = False
            self._last_checked = datetime.now().strftime("%H:%M")
            newer = rel["asset"] is not None and version_tuple(rel["tag"]) > version_tuple(__version__)
            self._release = rel if newer else None
            self._remote_hash = rel["tag"]
            self._remote_msg = rel["name"]
            self._commits_behind = 1 if newer else 0
            self._changelog = rel["notes"][:3000] if newer else ""
            self.changed.emit()
            if newer and (rel["tag"] != self._notified_hash or not silent):
                self._notified_hash = rel["tag"]
                self.toast.emit(f"Senada {rel['tag']} tersedia — klik Perbarui untuk memasangnya")
            elif not newer and not silent:
                self.toast.emit(f"Senada sudah versi terbaru ({self._current_hash})")

        def on_err(err):
            self._checking = False
            self.changed.emit()
            if not silent:
                self.toast.emit(f"Gagal memeriksa update: {err}")

        self.worker.run(_latest_release, on_ok, on_err)

    def _apply_release(self):
        if self._updating:
            return
        rel = self._release
        if not rel:  # nothing known yet: look first, the user can click again
            self.check(False)
            return
        asset = rel["asset"]
        self._updating = True
        self._progress = 0
        self.changed.emit()
        self.toast.emit(f"Mengunduh Senada {rel['tag']}…")

        def job():
            UPDATES_DIR.mkdir(parents=True, exist_ok=True)
            dest = UPDATES_DIR / asset["name"]
            part = dest.with_name(dest.name + ".part")
            total = int(asset.get("size") or 0)
            sha = hashlib.sha256()
            done = 0
            with _http(asset["browser_download_url"], timeout=60) as res, open(part, "wb") as f:
                while chunk := res.read(256 * 1024):
                    f.write(chunk)
                    sha.update(chunk)
                    done += len(chunk)
                    if total:
                        self._progressFromThread.emit(min(99, done * 100 // total))
            if total and done != total:
                part.unlink(missing_ok=True)
                raise RuntimeError("unduhan installer tidak lengkap")
            digest = asset.get("digest") or ""  # "sha256:<hex>", published by GitHub for release assets
            if digest.startswith("sha256:") and digest[7:].lower() != sha.hexdigest():
                part.unlink(missing_ok=True)
                raise RuntimeError("checksum installer tidak cocok")
            part.replace(dest)
            return dest

        def on_ok(path):
            self._progress = 100
            self.changed.emit()
            try:
                self.launch_installer(path)
            except OSError as e:
                on_err(e)
                return
            self.toast.emit(f"Memasang Senada {rel['tag']}… Senada akan terbuka lagi setelah selesai.")
            QTimer.singleShot(800, self.quitRequested.emit)

        def on_err(err):
            self._updating = False
            self._progress = -1
            self.changed.emit()
            self.toast.emit(f"Gagal memperbarui: {err}")

        self.worker.run(job, on_ok, on_err)
