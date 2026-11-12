"""Native see-through window backdrop for the "Transparan" glass mode.

Windows 10/11: the DWM draws acrylic (blurred desktop) behind the window.
Linux: the window just has an alpha channel; Hyprland, KDE (with a blur rule/effect)
and other compositors that blur translucent windows do the rest.
"""

import ctypes
import sys

DWMWA_USE_IMMERSIVE_DARK_MODE = 20
DWMWA_SYSTEMBACKDROP_TYPE = 38
DWMSBT_NONE = 1
DWMSBT_TRANSIENTWINDOW = 3  # acrylic


class _Margins(ctypes.Structure):
    _fields_ = [("left", ctypes.c_int), ("right", ctypes.c_int),
                ("top", ctypes.c_int), ("bottom", ctypes.c_int)]


def apply_backdrop(window, see_through: bool, theme: str = "system") -> None:
    if sys.platform != "win32":
        return
    try:
        hwnd = int(window.winId())
        dwm = ctypes.windll.dwmapi
        if theme in ("dark", "light"):
            dark = ctypes.c_int(1 if theme == "dark" else 0)
            dwm.DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ctypes.byref(dark), ctypes.sizeof(dark))
        extend = -1 if see_through else 0
        margins = _Margins(extend, extend, extend, extend)
        dwm.DwmExtendFrameIntoClientArea(hwnd, ctypes.byref(margins))
        kind = ctypes.c_int(DWMSBT_TRANSIENTWINDOW if see_through else DWMSBT_NONE)
        dwm.DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ctypes.byref(kind), ctypes.sizeof(kind))
    except (AttributeError, OSError):
        pass  # older Windows without these DWM attributes: plain translucency only
