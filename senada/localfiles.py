"""Music files on this computer ("Local files"), played next to the YouTube Music catalog.

Folders are picked in Settings → Profile & Library and scanned off the UI thread. Each file
becomes a track with the uri "local:file:<path>", so it goes in the queue, playlists and liked
songs like any other song; mpv plays the file itself. Tags (title, artist, album, length) and
the embedded cover are read with mutagen when it is installed, otherwise the file name is used
("Artist - Title"). An .lrc file next to a song gives it its lyrics. What was read is kept in
localfiles.json, so a rescan only reads the files that changed.
"""

import hashlib
import logging
import os
import re
import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot

from .config import CACHE_DIR, CONFIG_DIR, read_json, write_private
from .i18n import tr, trn

try:
    import mutagen
except ImportError:  # tags fall back to the file name
    mutagen = None

logger = logging.getLogger("senada.localfiles")

INDEX_FILE = CONFIG_DIR / "localfiles.json"
COVERS_DIR = CACHE_DIR / "covers"
AUDIO_EXT = {".mp3", ".flac", ".m4a", ".mp4", ".aac", ".ogg", ".oga", ".opus", ".wav", ".wma", ".aiff", ".aif", ".ape", ".wv"}
PREFIX = "local:file:"
NAME_RE = re.compile(r"^\s*(?:\d+[\s.\-_]+)?(?P<artist>.+?)\s+-\s+(?P<title>.+)$")


def is_local(uri: str) -> bool:
    return (uri or "").startswith(PREFIX)


def path_of(uri: str) -> str:
    return uri[len(PREFIX):] if is_local(uri) else ""


def _first(tags, *keys) -> str:
    for k in keys:
        try:
            v = tags.get(k) if tags is not None else None
        except (KeyError, ValueError, TypeError):
            v = None
        if v:
            v = v[0] if isinstance(v, list) else v
            text = str(v.text[0] if hasattr(v, "text") and v.text else v).strip()
            if text:
                return text
    return ""


def _cover_bytes(audio) -> bytes:
    """The picture embedded in the file (ID3 APIC, MP4 covr, FLAC / Vorbis picture)."""
    if audio is None:
        return b""
    try:
        pictures = getattr(audio, "pictures", None)
        if pictures:
            return pictures[0].data
        tags = audio.tags
        if tags is None:
            return b""
        if hasattr(tags, "getall"):
            frames = tags.getall("APIC")
            if frames:
                return frames[0].data
        covr = tags.get("covr") if hasattr(tags, "get") else None
        if covr:
            return bytes(covr[0])
        block = tags.get("metadata_block_picture") if hasattr(tags, "get") else None
        if block:
            import base64
            from mutagen.flac import Picture
            return Picture(base64.b64decode(block[0])).data
    except Exception as e:  # a damaged tag is no reason to skip the song
        logger.debug("no cover in %s: %s", getattr(audio, "filename", "?"), e)
    return b""


def save_cover(data: bytes) -> str:
    """The cover as a cached file (one per distinct picture), as a file:// url."""
    if not data:
        return ""
    COVERS_DIR.mkdir(parents=True, exist_ok=True)
    path = COVERS_DIR / (hashlib.sha1(data).hexdigest()[:20] + ".img")
    if not path.exists():
        path.write_bytes(data)
    return QUrl.fromLocalFile(str(path)).toString()


def read_track(path: Path) -> dict:
    """A track dict for one audio file."""
    title, artist, album, duration, cover = "", "", "", 0, ""
    if mutagen is not None:
        try:
            easy = mutagen.File(str(path), easy=True)
            if easy is not None:
                title = _first(easy.tags, "title")
                artist = _first(easy.tags, "artist", "albumartist")
                album = _first(easy.tags, "album")
                duration = int((getattr(easy.info, "length", 0) or 0) * 1000)
            cover = save_cover(_cover_bytes(mutagen.File(str(path))))
        except Exception as e:  # unreadable tags: the file name still names it
            logger.debug("tags of %s not read: %s", path, e)
    if not title:
        m = NAME_RE.match(path.stem)
        title = m.group("title").strip() if m else path.stem
        artist = artist or (m.group("artist").strip() if m else "")
    return {"uri": PREFIX + str(path), "id": "", "name": title, "artists": artist or tr("Unknown artist"),
            "album": album or path.parent.name, "durationMs": duration, "explicit": False,
            "imageSmall": cover, "image": cover, "imageLarge": cover, "local": True}


def scan(folders: list[str], old: dict) -> dict:
    """{path: {"mtime", "track"}} for every audio file under the folders; unchanged files keep
    what was read before."""
    out = {}
    for folder in folders:
        for root, _dirs, files in os.walk(folder):
            for name in files:
                path = Path(root) / name
                if path.suffix.lower() not in AUDIO_EXT:
                    continue
                key = str(path)
                try:
                    mtime = path.stat().st_mtime
                except OSError:
                    continue
                before = old.get(key)
                if before and before.get("mtime") == mtime:
                    out[key] = before
                else:
                    out[key] = {"mtime": mtime, "track": read_track(path)}
    return out


def sort_key(track: dict):
    return (track.get("artists", "").lower(), track.get("album", "").lower(), track.get("name", "").lower())


class LocalFiles(QObject):
    changed = Signal()
    toast = Signal(str)
    _scanned = Signal(object)   # from the scanning thread

    def __init__(self, settings, parent=None):
        super().__init__(parent)
        self.settings = settings
        self._lock = threading.Lock()
        self._index = read_json(INDEX_FILE).get("files") or {}
        self._scanning = False
        self._scanned.connect(self._on_scanned)

    # ---- for the player, the catalog and the lyrics ----------------------------------------

    def tracks(self) -> list[dict]:
        with self._lock:
            return sorted((dict(e["track"]) for e in self._index.values()), key=sort_key)

    def path_for(self, uri: str) -> str | None:
        path = path_of(uri)
        return path if path and os.path.isfile(path) else None

    def lyrics_for(self, uri: str) -> dict | None:
        """An .lrc file next to the song: {"synced", "lines", "source"}."""
        path = path_of(uri)
        if not path:
            return None
        lrc = Path(path).with_suffix(".lrc")
        try:
            text = lrc.read_text(encoding="utf-8-sig", errors="replace")
        except OSError:
            return None
        from .lyrics import _plain, parse_lrc
        lines = parse_lrc(text)
        data = {"synced": True, "lines": lines} if lines else _plain(text)
        return {**data, "source": "file"} if data["lines"] else None

    def page(self) -> dict:
        tracks = self.tracks()
        folders = self.folders
        if not folders:
            note = tr("Add a music folder in Settings → Profile & Library to play the songs on this computer.")
        elif not tracks:
            note = tr("Looking for songs…") if self._scanning else tr("No music files in these folders.")
        else:
            note = ""
        cover = next((t for t in tracks if t.get("imageSmall")), {})
        return {"kind": "local", "id": "", "uri": "senada:local:", "name": tr("Local files"),
                "imageSmall": cover.get("imageSmall", ""), "image": cover.get("image", ""),
                "imageLarge": cover.get("imageLarge", ""), "typeLabel": tr("On this computer"),
                "subtitle": trn("{n} song", "{n} songs", len(tracks)), "tracks": tracks,
                "playUri": "senada:local:", "note": note, "local": True}

    # ---- QML ---------------------------------------------------------------------------------

    @Property("QVariantList", notify=changed)
    def folders(self):
        return list(self.settings["local_folders"] or [])

    @Property(int, notify=changed)
    def count(self):
        with self._lock:
            return len(self._index)

    @Property(bool, notify=changed)
    def scanning(self):
        return self._scanning

    @Property(bool, constant=True)
    def readsTags(self):
        return mutagen is not None

    @Slot(QUrl)
    def addFolder(self, url):
        path = url.toLocalFile() if isinstance(url, QUrl) else str(url)
        path = os.path.normpath(path) if path else ""
        if not path or not os.path.isdir(path) or path in self.folders:
            return
        self.settings["local_folders"] = self.folders + [path]
        self.changed.emit()
        self.rescan()

    @Slot(str)
    def removeFolder(self, path):
        if path in self.folders:
            self.settings["local_folders"] = [f for f in self.folders if f != path]
            self.changed.emit()
            self.rescan()

    @Slot()
    def rescan(self):
        if self._scanning:
            return
        self._scanning = True
        self.changed.emit()
        folders = [f for f in self.folders if os.path.isdir(f)]
        with self._lock:
            old = dict(self._index)

        def work():
            try:
                found = scan(folders, old)
            except Exception as e:  # never let a strange folder take the scan thread down quietly
                logger.warning("scan failed: %s", e)
                found = old
            self._scanned.emit(found)

        threading.Thread(target=work, name="senada-localfiles", daemon=True).start()

    def _on_scanned(self, found):
        with self._lock:
            before = len(self._index)
            self._index = found
        self._scanning = False
        try:
            write_private(INDEX_FILE, {"files": found})
        except OSError as e:
            logger.warning("local files index not saved: %s", e)
        self.changed.emit()
        if len(found) != before:
            self.toast.emit(trn("{n} song in your music folders", "{n} songs in your music folders", len(found)))
