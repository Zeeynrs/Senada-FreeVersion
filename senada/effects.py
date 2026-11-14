"""Equalizer and tempo settings shared by every full view style.

The full view draws these controls in several ways (the classic panel, the turntable's
spokes, the poster's fine sliders); they all read and change this one object, so a change
in one style shows in the others and survives a restart. Saving waits a moment so that
dragging a slider does not write the settings file on every step. Every change also goes
straight to the audio engine (mpv): the bands as an equalizer filter, the tempo as its speed.
"""

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

BANDS = ("60", "150", "400", "1k", "2k", "15k")
# band gains from -1 to +1 (shown as ±12 dB)
PRESETS = {
    "Custom": [0.36, 0.14, -0.02, -0.10, -0.08, -0.08],
    "Bass Boost": [0.65, 0.45, 0.10, -0.05, 0.00, 0.05],
    "Rock": [0.45, 0.22, -0.15, 0.12, 0.32, 0.42],
    "Vocal": [-0.15, 0.05, 0.38, 0.48, 0.25, -0.05],
    "Flat": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
}
MAX_DB = 12
TEMPO_MIN, TEMPO_MAX = 0.5, 2.0
# flat by default: the sound is left as it is until the user changes it
DEFAULTS = {"enabled": True, "preset": "Flat", "bands": PRESETS["Flat"], "tempo": 1.0, "keepPitch": False}


def gains_db(state: dict) -> list[float] | None:
    """The equalizer's band gains in dB, or None when it is off or flat (no filter at all)."""
    if not state["enabled"]:
        return None
    gains = [round(float(b) * MAX_DB, 2) for b in state["bands"]]
    return gains if any(abs(g) >= 0.05 for g in gains) else None


class AudioEffects(QObject):
    changed = Signal()

    def __init__(self, settings, engine=None, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.engine = engine
        saved = settings["effects"] or {}
        self._state = {**DEFAULTS, **{k: v for k, v in saved.items() if k in DEFAULTS}}
        bands = self._state["bands"]
        if not isinstance(bands, list) or len(bands) != len(BANDS):
            self._state["bands"] = list(DEFAULTS["bands"])
        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(600)
        self._save_timer.timeout.connect(self._save)
        self._apply()

    def _apply(self):
        if self.engine is None:
            return
        self.engine.set_tempo(self._state["tempo"], self._state["keepPitch"])
        self.engine.set_equalizer(gains_db(self._state))

    def _save(self):
        self.settings["effects"] = dict(self._state)

    def _update(self, **values):
        changed = {k: v for k, v in values.items() if self._state.get(k) != v}
        if not changed:
            return
        self._state.update(changed)
        self._apply()
        self.changed.emit()
        self._save_timer.start()

    # ---- QML ------------------------------------------------------------------------

    @Property("QVariantList", constant=True)
    def bandLabels(self):
        return list(BANDS)

    @Property("QVariantList", constant=True)
    def presetNames(self):
        return list(PRESETS)

    @Property(bool, notify=changed)
    def enabled(self):
        return bool(self._state["enabled"])

    @Property(str, notify=changed)
    def preset(self):
        return self._state["preset"]

    @Property("QVariantList", notify=changed)
    def bands(self):
        return list(self._state["bands"])

    @Property(float, notify=changed)
    def tempo(self):
        return float(self._state["tempo"])

    @Property(bool, notify=changed)
    def keepPitch(self):
        return bool(self._state["keepPitch"])

    @Slot(bool)
    def setEnabled(self, on):
        self._update(enabled=bool(on))

    @Slot(int, float)
    def setBand(self, index, value):
        if not 0 <= index < len(BANDS):
            return
        bands = list(self._state["bands"])
        bands[index] = round(max(-1.0, min(1.0, float(value))), 3)
        self._update(bands=bands, preset="Custom")

    @Slot(str)
    def usePreset(self, name):
        if name in PRESETS:
            self._update(preset=name, bands=list(PRESETS[name]))

    @Slot()
    def nextPreset(self):
        names = list(PRESETS)
        i = (names.index(self._state["preset"]) + 1) % len(names) if self._state["preset"] in names else 0
        self.usePreset(names[i])

    @Slot(float)
    def setTempo(self, value):
        self._update(tempo=round(max(TEMPO_MIN, min(TEMPO_MAX, float(value))), 2))

    @Slot(bool)
    def setKeepPitch(self, on):
        self._update(keepPitch=bool(on))
