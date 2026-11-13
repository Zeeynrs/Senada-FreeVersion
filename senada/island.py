"""Window rules for the mini player ("dynamic island", qml/MiniPlayer.qml) on Hyprland.

A Wayland app cannot place its own windows, so on Hyprland Senada asks the compositor to
float the mini player at the top centre of the screen, on every workspace, without a
border, shadow or blur, and without taking the keyboard focus. Windows and X11 place it
from QML; other Wayland desktops put it where they put new windows.
"""

import json
import os
import shutil
import subprocess

TITLE = "Senada mini player"  # MiniPlayer.qml's title: the rules match it
SIZE = (504, 454)  # MiniPlayer.qml's window: the widest pill plus its margins
_MATCH = f"^({TITLE})$"


def _position(reserved=(0, 0, 0, 0)) -> tuple[str, str]:
    """Centred in the part of the screen bars leave free (reserved = left, top, right, bottom)."""
    left, top, right, _ = reserved
    return f"({left}+(monitor_w-{left + right})*0.5-window_w*0.5)", f"({top})"


def lua_rule(reserved=(0, 0, 0, 0)) -> str:
    """Hyprland 0.55+ (Lua config): one named rule, so adding it again replaces it."""
    x, y = _position(reserved)
    return (
        'hl.window_rule({name = "senada-mini-player", match = {title = "%s"}, '
        "float = true, pin = true, no_initial_focus = true, no_shadow = true, no_blur = true, "
        "no_dim = true, border_size = 0, rounding = 0, size = {%d, %d}, "
        'move = {"%s", "%s"}})' % (_MATCH, *SIZE, x, y)
    )


def legacy_rules(reserved=(0, 0, 0, 0)) -> str:
    """Older Hyprland (hyprlang config, 0.48 – 0.54), for `hyprctl --batch`."""
    x, y = _position(reserved)
    rules = ("float", "pin", "noinitialfocus", "noshadow", "noblur", "nodim", "bordersize 0",
             "rounding 0", "size %d %d" % SIZE, f"move {x} {y}")
    return " ; ".join(f"keyword windowrule {r}, title:{_MATCH}" for r in rules)


def _reserved() -> tuple:
    """Room the bars take on the focused monitor."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=2)
        for m in json.loads(out.stdout):
            if m.get("focused"):
                r = tuple(int(v) for v in m.get("reserved", ()))
                return r if len(r) == 4 else (0, 0, 0, 0)
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        pass
    return (0, 0, 0, 0)


def prepare() -> None:
    """Add the rules (again: a config reload drops rules added at runtime). Quietly does
    nothing outside Hyprland or when hyprctl is missing or fails."""
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not shutil.which("hyprctl"):
        return
    reserved = _reserved()
    try:
        out = subprocess.run(["hyprctl", "eval", lua_rule(reserved)], capture_output=True, text=True, timeout=2)
        if out.returncode == 0 and out.stdout.strip() == "ok":
            return
        subprocess.run(["hyprctl", "--batch", legacy_rules(reserved)], capture_output=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        pass
