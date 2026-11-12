"""Turn the app logo (data/senada.png, or an SVG) into a multi-size Windows .ico (PNG entries)."""

import os
import struct
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QBuffer, QByteArray, QIODevice, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication, QImage, QPainter  # noqa: E402
from PySide6.QtSvg import QSvgRenderer  # noqa: E402

SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def to_png(img: QImage) -> bytes:
    data = QByteArray()
    buf = QBuffer(data)
    buf.open(QIODevice.OpenModeFlag.WriteOnly)
    img.save(buf, "PNG")
    return bytes(data)


def render(src: Path, size: int) -> QImage:
    if src.suffix.lower() == ".svg":
        renderer = QSvgRenderer(str(src))
        if not renderer.isValid():
            sys.exit(f"Tidak bisa membaca {src}")
        img = QImage(size, size, QImage.Format.Format_ARGB32_Premultiplied)
        img.fill(Qt.GlobalColor.transparent)
        painter = QPainter(img)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        renderer.render(painter)
        painter.end()
        return img
    master = QImage(str(src))
    if master.isNull():
        sys.exit(f"Tidak bisa membaca {src}")
    return master.scaled(size, size, Qt.AspectRatioMode.KeepAspectRatio,
                         Qt.TransformationMode.SmoothTransformation)


def main(src: Path, out: Path) -> None:
    _app = QGuiApplication(sys.argv[:1])
    pngs = [to_png(render(src, s)) for s in SIZES]
    header = struct.pack("<HHH", 0, 1, len(SIZES))
    offset = len(header) + 16 * len(SIZES)
    entries, blobs = b"", b""
    for size, png in zip(SIZES, pngs):
        dim = 0 if size >= 256 else size  # 0 means 256 in the ICO directory
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset)
        offset += len(png)
        blobs += png
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(header + entries + blobs)
    print(f"Ikon dibuat: {out}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
