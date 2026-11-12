pragma Singleton
import QtQuick

// Senada "Bloom" design tokens: ink base, glass layers, mint + fuchsia brand colours.
// `accent` stays album-adaptive (immersive visualizer & ambience); brand colours are fixed.
QtObject {
    // base & surfaces (ink-tinted, used under/behind glass)
    readonly property color bg: "#0b0f14"
    readonly property color surface: "#111720"
    readonly property color surface2: "#17202b"
    readonly property color surface3: "#202b37"

    // text
    readonly property color text: "#f2f5f7"
    readonly property color dim: "#9aa6b2"
    readonly property color faint: "#5f6b78"

    // brand
    readonly property color mint: "#6ff2c6"
    readonly property color fuchsia: "#ff4f8b"
    readonly property color primary: mint
    readonly property color primaryText: "#04251a"
    readonly property color accentText: primaryText
    readonly property color danger: "#ff6b81"
    readonly property color ok: "#6ff2c6"

    // album-adaptive colour (set by Main.qml from the cover art)
    property color accent: "#6ff2c6"

    // glass: white veils on top of the blurred album backdrop
    readonly property color glass: Qt.rgba(1, 1, 1, 0.06)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color glassStrong: Qt.rgba(1, 1, 1, 0.14)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.09)
    readonly property color panel: Qt.rgba(0.067, 0.086, 0.114, 0.94)  // floating bars (dock)

    readonly property int dockSpace: 132  // scroll padding so content clears the floating dock

    readonly property string font: "Google Sans Flex"
    readonly property string mono: "JetBrainsMono Nerd Font"

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

    function fmt(ms) {
        const total = Math.max(0, Math.floor((ms || 0) / 1000))
        const s = total % 60
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" : "") + s
    }

    function greeting() {
        const h = new Date().getHours()
        if (h < 11) return "Selamat pagi"
        if (h < 15) return "Selamat siang"
        if (h < 19) return "Selamat sore"
        return "Selamat malam"
    }
}
