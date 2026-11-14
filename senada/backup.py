"""Back up the library (and the settings) to one file, and bring it back.

A backup is a JSON file: liked songs, own playlists, saved albums / artists / playlists,
history and the settings. Offline songs are not in it (the audio is large and can be
downloaded again). Restoring either adds what is missing to the library ("merge": nothing
is lost) or replaces it; the settings come back only when asked, after a restart.
Before a restore, and once a week on its own, Senada keeps a copy of the library in
<config>/backups (the last few), so a bad restore or a damaged file can be undone.
"""

import copy
import datetime
import json
import logging
import time
from pathlib import Path

from PySide6.QtCore import Property, QObject, QStandardPaths, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices

from . import __version__
from .config import CONFIG_DIR, write_private
from .i18n import tr
from .store import HISTORY_LIMIT

logger = logging.getLogger("senada.backup")

FORMAT = 1
AUTO_DIR = CONFIG_DIR / "backups"
AUTO_KEEP = 5                 # copies kept in AUTO_DIR
AUTO_EVERY = 7 * 24 * 3600    # seconds between automatic copies
LIBRARY_KEYS = ("liked", "playlists", "saved", "history")


class BackupError(ValueError):
    """The file is not a Senada backup (the message says why, for the user)."""


def make_backup(library: dict, settings: dict | None) -> dict:
    out = {"app": "Senada", "kind": "backup", "format": FORMAT, "senadaVersion": __version__,
           "created": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "library": {k: copy.deepcopy(library.get(k) or []) for k in LIBRARY_KEYS}}
    if settings is not None:
        out["settings"] = copy.deepcopy(settings)
    return out


def read_backup(path) -> dict:
    """The backup in `path`, checked; a bare library.json is taken as a backup without settings."""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as e:
        raise BackupError(tr("The file could not be read.")) from e
    except ValueError as e:
        raise BackupError(tr("This file is not a Senada backup.")) from e
    if not isinstance(data, dict):
        raise BackupError(tr("This file is not a Senada backup."))
    if data.get("app") == "Senada" and data.get("kind") == "backup":
        if int(data.get("format") or 0) > FORMAT:
            raise BackupError(tr("This backup was made by a newer Senada. Update Senada first."))
        library = data.get("library")
    elif any(k in data for k in LIBRARY_KEYS):  # library.json copied by hand
        library, data = data, {"created": ""}
    else:
        raise BackupError(tr("This file is not a Senada backup."))
    if not isinstance(library, dict):
        raise BackupError(tr("This file is not a Senada backup."))
    clean = {}
    for k in LIBRARY_KEYS:
        items = library.get(k) or []
        if not isinstance(items, list):
            raise BackupError(tr("This backup is damaged."))
        clean[k] = [i for i in items if isinstance(i, dict)]
    settings = data.get("settings")
    return {"created": data.get("created") or "", "senadaVersion": data.get("senadaVersion") or "",
            "library": clean, "settings": settings if isinstance(settings, dict) else None}


def summary(backup: dict) -> dict:
    lib = backup["library"]
    return {"liked": len(lib["liked"]), "playlists": len(lib["playlists"]), "saved": len(lib["saved"]),
            "history": len(lib["history"]), "hasSettings": backup["settings"] is not None,
            "created": backup["created"][:16].replace("T", " ")}


def _by(items, key):
    return {key(i): i for i in items}


def merge_library(current: dict, incoming: dict) -> dict:
    """The current library with what the backup has and it lacks: nothing is removed or renamed."""
    out = copy.deepcopy(current)
    have = _by(out["liked"], lambda t: t.get("uri"))
    out["liked"] += [copy.deepcopy(t) for t in incoming["liked"] if t.get("uri") and t["uri"] not in have]
    out["liked"].sort(key=lambda t: t.get("addedAt") or 0, reverse=True)

    lists = _by(out["playlists"], lambda p: p.get("id"))
    for p in incoming["playlists"]:
        mine = lists.get(p.get("id"))
        if mine is None:
            out["playlists"].append(copy.deepcopy(p))
            continue
        uris = {t.get("uri") for t in mine.get("tracks") or []}
        mine.setdefault("tracks", []).extend(copy.deepcopy(t) for t in p.get("tracks") or []
                                             if t.get("uri") and t["uri"] not in uris)
    out["playlists"].sort(key=lambda p: p.get("created") or 0, reverse=True)

    saved = _by(out["saved"], lambda s: (s.get("kind"), s.get("id")))
    out["saved"] += [copy.deepcopy(s) for s in incoming["saved"] if (s.get("kind"), s.get("id")) not in saved]

    seen = _by(out["history"], lambda t: t.get("uri"))
    out["history"] += [copy.deepcopy(t) for t in incoming["history"] if t.get("uri") and t["uri"] not in seen]
    out["history"].sort(key=lambda t: t.get("playedAt") or 0, reverse=True)
    out["history"] = out["history"][:HISTORY_LIMIT]
    return out


def keep_copy(library: dict, settings: dict | None, reason: str, folder: Path | None = None,
              keep: int = AUTO_KEEP) -> Path:
    """Write a copy to `folder` (AUTO_DIR) and drop the oldest others beyond `keep`."""
    folder = folder or AUTO_DIR
    folder.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y-%m-%d %H-%M-%S")
    path = folder / f"Senada {reason} {stamp}.json"
    write_private(path, make_backup(library, settings))
    # the copy just written always stays
    others = sorted((p for p in folder.glob("Senada *.json") if p != path),
                    key=lambda p: p.stat().st_mtime, reverse=True)
    for old in others[max(0, keep - 1):]:
        try:
            old.unlink()
        except OSError:
            pass
    return path


def weekly_copy_due(folder: Path | None = None, every: float = AUTO_EVERY) -> bool:
    folder = folder or AUTO_DIR
    copies = list(folder.glob("Senada *.json")) if folder.is_dir() else []
    newest = max((p.stat().st_mtime for p in copies), default=0)
    return time.time() - newest >= every


class Backup(QObject):
    """Settings → Profile & Library: back up, restore, and the automatic copies."""
    toast = Signal(str)
    restartRequested = Signal()   # settings were restored: they apply from the next start
    restored = Signal()           # the library changed

    def __init__(self, store, settings, parent=None):
        super().__init__(parent)
        self.store = store
        self.settings = settings

    def weekly(self):
        """An automatic copy once a week, called at start (an empty library is not copied)."""
        library = self.store.snapshot()
        if any(library.values()) and weekly_copy_due():
            try:
                keep_copy(library, self.settings.snapshot(), "auto")
            except OSError as e:
                logger.warning("automatic backup failed: %s", e)

    # ---- QML ------------------------------------------------------------------------

    @Property(str, constant=True)
    def suggestedName(self):
        return tr("Senada backup") + " " + time.strftime("%Y-%m-%d") + ".json"

    @Property(QUrl, constant=True)
    def suggestedFolder(self):
        docs = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DocumentsLocation)
        return QUrl.fromLocalFile(docs or str(Path.home()))

    @Property(str, constant=True)
    def autoFolder(self):
        return str(AUTO_DIR)

    @Slot()
    def openAutoFolder(self):
        AUTO_DIR.mkdir(parents=True, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(AUTO_DIR)))

    @Slot(QUrl, result=bool)
    def exportTo(self, url):
        path = Path(url.toLocalFile())
        if path.suffix.lower() != ".json":
            path = path.with_suffix(".json")
        try:
            write_private(path, make_backup(self.store.snapshot(), self.settings.snapshot()))
        except OSError as e:
            logger.warning("backup failed: %s", e)
            self.toast.emit(tr("The backup could not be saved: {error}", error=e.strerror or str(e)))
            return False
        self.toast.emit(tr("Backup saved: {name}", name=path.name))
        return True

    @Slot(QUrl, result="QVariantMap")
    def inspect(self, url):
        """What a backup holds, for the restore dialog: {ok, error, liked, playlists, saved, history, …}."""
        try:
            return {"ok": True, "error": "", **summary(read_backup(url.toLocalFile()))}
        except BackupError as e:
            return {"ok": False, "error": str(e)}

    @Slot(QUrl, str, bool, result=bool)
    def restore(self, url, mode, with_settings):
        """mode "merge" adds what is missing, "replace" swaps the library for the backup's."""
        try:
            backup = read_backup(url.toLocalFile())
        except BackupError as e:
            self.toast.emit(str(e))
            return False
        current = self.store.snapshot()
        try:
            keep_copy(current, self.settings.snapshot(), "before restore")
        except OSError as e:  # without the safety copy the restore does not go ahead
            self.toast.emit(tr("The backup could not be saved: {error}", error=e.strerror or str(e)))
            return False
        library = backup["library"] if mode == "replace" else merge_library(current, backup["library"])
        self.store.replace(library)
        self.restored.emit()
        if with_settings and backup["settings"]:
            self.settings.restore(backup["settings"])
            self.toast.emit(tr("Library restored. Senada restarts to apply the settings."))
            self.restartRequested.emit()
        else:
            self.toast.emit(tr("Library restored."))
        return True
