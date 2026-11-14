@echo off
rem Senada for Windows: sets up a private Python environment on first run, then starts the app.
setlocal
cd /d "%~dp0"

where py >/dev/null 2>/dev/null && (set "PY=py -3") || (set "PY=python")

if not exist ".venv\Scripts\pythonw.exe" (
    echo Menyiapkan Senada untuk pertama kali...
    %PY% -m venv .venv || goto :nopython
    ".venv\Scripts\python.exe" -m pip install --upgrade pip
    ".venv\Scripts\python.exe" -m pip install PySide6 || goto :nopip
)

rem Windows media controls (media keys, the volume flyout); Senada still starts without them
".venv\Scripts\python.exe" -c "import winrt.windows.media.playback, winrt.windows.storage.streams" 2>nul || (
    ".venv\Scripts\python.exe" -m pip install --quiet winrt-runtime winrt-Windows.Foundation winrt-Windows.Media winrt-Windows.Media.Playback winrt-Windows.Storage.Streams
)

if not exist "bin\mpv.exe" (
    where mpv >/dev/null 2>/dev/null || (
        echo mpv.exe tidak ditemukan. Taruh mpv.exe dan yt-dlp.exe di folder "bin" Senada,
        echo atau pasang lewat Scoop:  scoop bucket add extras ^&^& scoop install mpv yt-dlp
        pause
        exit /b 1
    )
)

start "" ".venv\Scripts\pythonw.exe" run.py %*
exit /b 0

:nopython
echo Python 3.11+ belum terpasang. Pasang dari https://www.python.org/downloads/ (centang "Add python.exe to PATH").
pause
exit /b 1

:nopip
echo Gagal memasang PySide6. Periksa koneksi internet lalu jalankan lagi.
pause
exit /b 1
