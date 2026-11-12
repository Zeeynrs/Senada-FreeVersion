"""Download the helper programs bundled with the Windows build: mpv.exe, yt-dlp.exe, deno.exe.

    python fetch_tools.py <output dir>

Files that are already present are kept, so delete them to force a fresh download.
mpv comes from the shinchiro builds that mpv.io links to (baseline x86_64, runs on any
64-bit CPU) and is unpacked with 7-Zip (an installed 7z, or the official 7zr.exe, downloaded
next to <output dir>); yt-dlp and deno (the JavaScript runtime yt-dlp needs for YouTube)
from their own GitHub releases, checked against the published SHA-256.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

MPV_RELEASES = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
MPV_ASSET = re.compile(r"^mpv-x86_64-\d{8}-git-[0-9a-f]+\.7z$")
YTDLP_BASE = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/"
DENO_BASE = "https://github.com/denoland/deno/releases/latest/download/"
DENO_ZIP = "deno-x86_64-pc-windows-msvc.zip"
SEVENZR_URL = "https://www.7-zip.org/a/7zr.exe"  # standalone 7-Zip console extractor


def _request(url: str) -> urllib.request.Request:
    headers = {"User-Agent": "senada-windows-build"}
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    return urllib.request.Request(url, headers=headers)


def _download(url: str, dest: Path) -> None:
    print(f"  mengunduh {url}")
    with urllib.request.urlopen(_request(url), timeout=120) as res, open(dest, "wb") as f:
        shutil.copyfileobj(res, f)


def _sevenzip(cache: Path) -> str:
    """A 7-Zip that handles mpv's archives (LZMA2 + BCJ2): installed 7z, else the official 7zr.exe."""
    for cand in (shutil.which("7z"), shutil.which("7za"), shutil.which("7zr"),
                 os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "7-Zip", "7z.exe")):
        if cand and os.path.isfile(cand):
            return cand
    exe = cache / "7zr.exe"
    if not exe.is_file():
        _download(SEVENZR_URL, exe)
    return str(exe)


def fetch_mpv(out: Path) -> None:
    if (out / "mpv.exe").is_file():
        print("mpv.exe sudah ada, dilewati")
        return
    with urllib.request.urlopen(_request(MPV_RELEASES), timeout=60) as res:
        release = json.load(res)
    asset = next((a for a in release["assets"] if MPV_ASSET.match(a["name"])), None)
    if not asset:
        sys.exit("Tidak menemukan build mpv x86_64 di rilis terbaru shinchiro/mpv-winbuild-cmake")
    sevenzip = _sevenzip(out.parent)
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / asset["name"]
        _download(asset["browser_download_url"], archive)
        extract = Path(tmp) / "mpv"
        res = subprocess.run([sevenzip, "x", "-y", f"-o{extract}", str(archive)], capture_output=True, text=True)
        if res.returncode != 0:
            sys.exit(f"Gagal mengekstrak arsip mpv:\n{res.stdout}{res.stderr}")
        exe = next(extract.rglob("mpv.exe"), None)
        if not exe:
            sys.exit("mpv.exe tidak ada di dalam arsip mpv")
        for f in exe.parent.iterdir():  # mpv.exe plus any DLLs it ships with
            if f.suffix.lower() in (".exe", ".dll") and f.name.lower() != "updater.bat":
                shutil.copy2(f, out / f.name)
        print(f"mpv siap ({asset['name']})")


def fetch_ytdlp(out: Path) -> None:
    dest = out / "yt-dlp.exe"
    if dest.is_file():
        print("yt-dlp.exe sudah ada, dilewati")
        return
    with urllib.request.urlopen(_request(YTDLP_BASE + "SHA2-256SUMS"), timeout=60) as res:
        sums = dict(line.split()[::-1] for line in res.read().decode().splitlines() if line.strip())
    tmp = dest.with_suffix(".part")
    _download(YTDLP_BASE + "yt-dlp.exe", tmp)
    digest = hashlib.sha256(tmp.read_bytes()).hexdigest()
    if sums.get("yt-dlp.exe") != digest:
        tmp.unlink()
        sys.exit("Checksum yt-dlp.exe tidak cocok, unduhan dibatalkan")
    tmp.replace(dest)
    print("yt-dlp siap (checksum cocok)")


def fetch_deno(out: Path) -> None:
    """yt-dlp needs a JavaScript runtime for YouTube; it finds deno.exe on PATH (Senada puts bin\\ there)."""
    dest = out / "deno.exe"
    if dest.is_file():
        print("deno.exe sudah ada, dilewati")
        return
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / DENO_ZIP
        _download(DENO_BASE + DENO_ZIP, archive)
        with urllib.request.urlopen(_request(DENO_BASE + DENO_ZIP + ".sha256sum"), timeout=60) as res:
            expected = re.search(r"\b[0-9a-fA-F]{64}\b", res.read().decode("utf-8", "replace"))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if not expected or expected.group(0).lower() != digest:
            sys.exit("Checksum deno tidak cocok, unduhan dibatalkan")
        with zipfile.ZipFile(archive) as z:
            with z.open("deno.exe") as src, open(dest, "wb") as dst:
                shutil.copyfileobj(src, dst)
    print("deno siap (checksum cocok)")


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "tools")
    out.mkdir(parents=True, exist_ok=True)
    fetch_mpv(out)
    fetch_ytdlp(out)
    fetch_deno(out)


if __name__ == "__main__":
    main()
