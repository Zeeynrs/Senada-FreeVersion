"""Paths and persisted settings for Senada."""

import json
import os
import subprocess
import sys
from pathlib import Path

APP_ID = "senada"
IS_WINDOWS = sys.platform == "win32"
FROZEN = getattr(sys, "frozen", False)  # running from the PyInstaller build (Windows installer)
if FROZEN:
    ROOT = Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent))  # qml/, data/
    APP_DIR = Path(sys.executable).resolve().parent  # folder holding Senada.exe
else:
    ROOT = Path(__file__).resolve().parent.parent
    APP_DIR = ROOT
BIN_DIR = APP_DIR / "bin"  # optional bundled tools (mpv, yt-dlp), mainly for Windows

if IS_WINDOWS:
    # %APPDATA%\Senada for settings and the library, %LOCALAPPDATA%\Senada\Cache for caches
    CONFIG_DIR = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming") / "Senada"
    CACHE_DIR = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "Senada" / "Cache"
else:
    CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / APP_ID
    CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / APP_ID

# child processes (mpv, yt-dlp, git) must not flash a console window on Windows
NO_WINDOW = subprocess.CREATE_NO_WINDOW if IS_WINDOWS else 0
SETTINGS_FILE = CONFIG_DIR / "settings.json"
LIBRARY_FILE = CONFIG_DIR / "library.json"
AUDIO_CACHE = CACHE_DIR / "audio"
# songs downloaded to play without internet: in the user's Music folder, easy to find and back up
DOWNLOADS_DIR = Path(os.environ.get("SENADA_DOWNLOADS") or Path.home() / "Music" / "Senada")
DOWNLOADS_FILE = CONFIG_DIR / "downloads.json"
# senada.log and mpv.log: what happened, for when something does not work (%LOCALAPPDATA%\Senada\logs)
LOG_DIR = CACHE_DIR.parent / "logs" if IS_WINDOWS else CACHE_DIR / "logs"

DEFAULTS = {
    "language": "en",  # "en" or "id" (see i18n.py)
    "display_name": "",
    "theme": "system",  # "system", "dark", "light"
    "accent": "default",  # accent colour key, see Theme.accents in qml/Theme.qml
    "accent_strength": "vivid",  # "subtle" or "vivid" (adds a glow of the accent at the top of pages)
    "glass": "off",  # "off", "cover" (blurred album art behind), "desktop" (see-through window)
    "glass_opacity": 0.62,  # how opaque the glass panels are (0.3 - 0.9)
    "device_name": "Senada",
    "visualizer": True,
    "visualizer_style": "bars",
    "immersive_style": "visualizer",
    "seek_style": "line",  # seek bars: "line", "wave", "bars", "dots" (see qml/SeekTrack.qml)  # full view: "visualizer" (cover in a spectrum) or "vinyl" (turntable)
    "mini_player": True,  # small player at the top of the screen while the window is minimized
    "audio_quality": "best",  # 'best', 'high', 'medium'
    "cache_audio": True,
    "lyrics_source": "auto",
    "effects": {},  # equalizer and tempo (see effects.py)  # "auto", "lrclib", "ytmusic", "netease" (see lyrics.py)
}


def write_private(path: Path, data: dict) -> None:
    """Write JSON readable only by the current user."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


class Settings:
    def __init__(self):
        saved = read_json(SETTINGS_FILE)
        saved.pop("client_id", None)  # left over from the Spotify login era
        self._data = {**DEFAULTS, **saved}

    def __getitem__(self, key):
        return self._data.get(key, DEFAULTS.get(key))

    def __setitem__(self, key, value):
        if self._data.get(key) != value:
            self._data[key] = value
            write_private(SETTINGS_FILE, self._data)
