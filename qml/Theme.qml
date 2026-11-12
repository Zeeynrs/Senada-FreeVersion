pragma Singleton
import QtQuick

// Senada design tokens. Monochrome: the primary colour is white on the dark theme and
// black on the light theme; colour comes only from album art (`accent`, used by the
// immersive player) and the red "liked" heart.
QtObject {
    // "system" | "dark" | "light" (bound to session.themeMode in Main.qml)
    property string mode: "system"
    readonly property bool dark: mode === "dark" || (mode !== "light" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light)

    // glass look (bound to session in Main.qml): "off" | "cover" | "desktop"
    property string glassMode: "off"
    property real glassOpacity: 0.62
    readonly property bool glass: glassMode !== "off"

    // base & surfaces; with glass on, the big areas turn translucent
    readonly property color bgSolid: dark ? "#121212" : "#fafafa"
    readonly property color sidebarSolid: dark ? "#000000" : "#f0f0f0"
    readonly property color bg: glass ? alpha(bgSolid, glassOpacity * 0.8) : bgSolid           // content area
    readonly property color sidebar: glass ? alpha(sidebarSolid, Math.min(1, glassOpacity + 0.08)) : sidebarSolid
    readonly property color surface: glass ? (dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.55))
                                           : (dark ? "#1b1b1b" : "#ffffff")   // cards, now-playing card
    readonly property color surface2: dark ? "#222222" : "#ffffff"  // menus, popups, dialogs
    readonly property color surface3: dark ? "#2a2a2a" : "#e9e9e9"  // placeholders, tracks of sliders

    // text
    readonly property color text: dark ? "#f5f5f5" : "#111111"
    readonly property color dim: dark ? "#a3a3a3" : "#5c5c5c"
    readonly property color faint: dark ? "#6b6b6b" : "#9a9a9a"

    // lines & interaction fills
    readonly property color line: dark ? Qt.rgba(1, 1, 1, glass ? 0.14 : 0.12) : Qt.rgba(0, 0, 0, 0.11)
    // "liquid glass" sheen: a bright hairline along the top edge of glass panels
    readonly property color sheen: glass ? (dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.8)) : "transparent"
    readonly property color lineStrong: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.6)
    readonly property color subtle: dark ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.025)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.09)

    // monochrome primary: white on dark, black on light
    readonly property color primary: text
    readonly property color primaryText: dark ? "#000000" : "#ffffff"

    // semantic
    readonly property color like: "#ff3b4f"
    readonly property color danger: "#ff5a6a"
    readonly property color warn: "#f2b84b"
    readonly property color ok: dark ? "#7ddc9a" : "#1f8a4c"

    // album-adaptive colour (set by Main.qml from the cover art); used by the immersive player
    property color accent: primary

    readonly property int dockSpace: 32      // bottom padding of scrolling pages
    readonly property int sidebarWidth: 232
    readonly property int playerBarHeight: 88
    readonly property int rightPanelWidth: 340

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
