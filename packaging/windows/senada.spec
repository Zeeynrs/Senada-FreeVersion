# PyInstaller spec for the Windows build of Senada. Run through build.ps1, which first
# creates build\senada.ico; the result is dist\Senada\Senada.exe (+ _internal\).
import re
from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules
from PyInstaller.utils.win32.versioninfo import (FixedFileInfo, StringFileInfo, StringStruct,
                                                 StringTable, VarFileInfo, VarStruct,
                                                 VSVersionInfo)

HERE = Path(SPECPATH)
ROOT = HERE.parent.parent
VERSION = re.search(r'__version__\s*=\s*"([^"]+)"', (ROOT / "senada" / "__init__.py").read_text()).group(1)
nums = tuple(int(n) for n in re.findall(r"\d+", VERSION)[:4]) + (0,) * 4
nums = nums[:4]

version_info = VSVersionInfo(
    ffi=FixedFileInfo(filevers=nums, prodvers=nums),
    kids=[
        StringFileInfo([StringTable("040904B0", [
            StringStruct("CompanyName", "Zeeynrs"),
            StringStruct("FileDescription", "Senada Music Player"),
            StringStruct("FileVersion", VERSION),
            StringStruct("InternalName", "Senada"),
            StringStruct("LegalCopyright", "GPL-3.0"),
            StringStruct("OriginalFilename", "Senada.exe"),
            StringStruct("ProductName", "Senada"),
            StringStruct("ProductVersion", VERSION),
        ])]),
        VarFileInfo([VarStruct("Translation", [0x0409, 1200])]),
    ],
)

a = Analysis(
    [str(ROOT / "run.py")],
    pathex=[str(ROOT)],
    datas=[
        (str(ROOT / "qml"), "qml"),
        (str(ROOT / "data" / "senada.png"), "data"),
    ],
    hiddenimports=collect_submodules("senada"),
    # dbus/MPRIS is Linux-only; the rest is never used and only adds size
    excludes=["dbus", "tkinter", "unittest", "pydoc", "PySide6.QtWidgets"],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="Senada",
    icon=str(HERE / "build" / "senada.ico"),
    version=version_info,
    console=False,
    upx=False,
)
coll = COLLECT(exe, a.binaries, a.datas, name="Senada", upx=False)
