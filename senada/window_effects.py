"""Native see-through window backdrop for the "Transparan" glass mode.

Windows 11 (22H2+): the DWM draws acrylic (blurred desktop) behind the window through
DWMWA_SYSTEMBACKDROP_TYPE.
Windows 10: that attribute does not exist, and an extended DWM frame is drawn as a flat
grey/black sheet, so the blurred desktop comes from the window's accent policy instead
(SetWindowCompositionAttribute, the API the Windows 10 taskbar and Start menu use).
Linux: the window just has an alpha channel; Hyprland, KDE (with a blur rule/effect)
and other compositors that blur translucent windows do the rest.
"""

import ctypes
import sys

DWMWA_USE_IMMERSIVE_DARK_MODE = 20
DWMWA_SYSTEMBACKDROP_TYPE = 38
DWMSBT_NONE = 1
DWMSBT_TRANSIENTWINDOW = 3  # acrylic
WIN11_BACKDROP_BUILD = 22621  # first build with DWMWA_SYSTEMBACKDROP_TYPE

WCA_ACCENT_POLICY = 19
ACCENT_DISABLED = 0
ACCENT_ENABLE_BLURBEHIND = 3


class _Margins(ctypes.Structure):
    _fields_ = [("left", ctypes.c_int), ("right", ctypes.c_int),
                ("top", ctypes.c_int), ("bottom", ctypes.c_int)]


class _AccentPolicy(ctypes.Structure):
    _fields_ = [("AccentState", ctypes.c_int), ("AccentFlags", ctypes.c_int),
                ("GradientColor", ctypes.c_uint), ("AnimationId", ctypes.c_int)]


class _CompositionAttribute(ctypes.Structure):
    _fields_ = [("Attribute", ctypes.c_int), ("Data", ctypes.c_void_p), ("SizeOfData", ctypes.c_size_t)]


def _windows_build() -> int:
    try:
        return sys.getwindowsversion().build
    except AttributeError:
        return 0


def _set_accent(hwnd: int, state: int) -> None:
    accent = _AccentPolicy(state, 0, 0, 0)
    data = _CompositionAttribute(WCA_ACCENT_POLICY, ctypes.cast(ctypes.pointer(accent), ctypes.c_void_p),
                                 ctypes.sizeof(accent))
    ctypes.windll.user32.SetWindowCompositionAttribute(hwnd, ctypes.byref(data))


def apply_backdrop(window, see_through: bool, theme: str = "system") -> None:
    if sys.platform != "win32":
        return
    try:
        hwnd = int(window.winId())
        dwm = ctypes.windll.dwmapi
        if theme in ("dark", "light"):
            dark = ctypes.c_int(1 if theme == "dark" else 0)
            dwm.DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ctypes.byref(dark), ctypes.sizeof(dark))
        if _windows_build() >= WIN11_BACKDROP_BUILD:
            extend = -1 if see_through else 0
            margins = _Margins(extend, extend, extend, extend)
            dwm.DwmExtendFrameIntoClientArea(hwnd, ctypes.byref(margins))
            kind = ctypes.c_int(DWMSBT_TRANSIENTWINDOW if see_through else DWMSBT_NONE)
            dwm.DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ctypes.byref(kind), ctypes.sizeof(kind))
        else:
            _set_accent(hwnd, ACCENT_ENABLE_BLURBEHIND if see_through else ACCENT_DISABLED)
    except (AttributeError, OSError):
        pass  # very old Windows without these APIs: plain translucency only
