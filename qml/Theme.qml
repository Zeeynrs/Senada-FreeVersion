pragma Singleton
import QtQuick

// Senada design tokens. Monochrome by default: the primary colour is white on the dark
// theme and black on the light theme. An accent colour picked in Settings (`accentName`)
// takes over the primary colour (logo, play buttons, seek bar, switches, active icons) and
// marks what is current: the playing song, the open page, the sung lyric line, chosen chips.
// "vivid" strength also lights the top of the pages with it.
// Album art colours the immersive player (`accent`), and the whole app with the "Follow the song"
// accent ("song"), which takes the colour of the cover that is playing (monochrome until there is one).
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

    // accent colours; `colors` with more than one entry draws the logo as a gradient
    property string accentName: "default"
    readonly property var accents: [
        { key: "default", label: "Default", colors: [] },
        { key: "song", label: "Follow the song", colors: [] },   // see songAccent
        { key: "mint", label: "Mint", colors: ["#1ed760"] },
        { key: "indigo", label: "Indigo", colors: ["#5865f2"] },
        { key: "sky", label: "Sky", colors: ["#2aabee"] },
        { key: "aurora", label: "Aurora", colors: ["#8b5cf6"] },
        { key: "sunset", label: "Sunset", colors: ["#ff6b5a"] },
        { key: "ocean", label: "Ocean", colors: ["#14b8a6"] },
        { key: "forest", label: "Forest", colors: ["#65a30d"] },
        { key: "berry", label: "Berry", colors: ["#d946ef"] },
        { key: "amber", label: "Amber", colors: ["#f59e0b"] },
        { key: "rose", label: "Rose", colors: ["#f43f5e"] },
        { key: "carbon", label: "Carbon", colors: ["#8a8f98"] },
        { key: "chrome", label: "Chrome", colors: ["#ff6ad5", "#a78bfa", "#38bdf8"] }
    ]
    // the cover's colour (already eased between songs in Main.qml); a grey cover gives none
    readonly property bool songHasColor: accent.hslSaturation > 0.12
    readonly property var songAccent: ({ key: "song", label: "Follow the song",
                                         colors: songHasColor ? [accent.toString()] : [] })
    readonly property var accentInfo: accentName === "song" ? songAccent
                                     : (accents.find(a => a.key === accentName) || accents[0])
    readonly property bool accented: accentInfo.colors.length > 0
    function accentColors(a) { return a.colors.length > 0 ? a.colors : [text] }
    function accentMain(a) { return a.colors.length > 0 ? a.colors[Math.floor(a.colors.length / 2)] : text }

    property string accentStrength: "vivid"  // "subtle" | "vivid"

    // primary: the accent colour, or white on dark / black on light without one
    readonly property color primary: accentMain(accentInfo)
    readonly property color primaryText: !accented ? (dark ? "#000000" : "#ffffff")
                                         : luma(primary) > 0.55 ? "#000000" : "#ffffff"
    // the accent as text/icon colour, kept readable on a dark or light background
    function accentInkOn(darkBg) {
        if (!accented) return darkBg ? "#f5f5f5" : "#111111"
        return darkBg ? mix(primary, Qt.rgba(1, 1, 1, 1), 0.18) : mix(primary, Qt.rgba(0, 0, 0, 1), 0.28)
    }
    readonly property color accentInk: accentInkOn(dark)          // current item text & icons
    readonly property color selected: accented ? alpha(primary, dark ? 0.17 : 0.14) : hover  // current item fill
    readonly property bool glowOn: accented && accentStrength === "vivid"
    readonly property color glow: alpha(primary, glowOn ? (dark ? 0.26 : 0.18) : 0)  // top of the pages

    // semantic
    readonly property color like: "#ff3b4f"
    readonly property color danger: "#ff5a6a"
    readonly property color warn: "#f2b84b"
    readonly property color ok: dark ? "#7ddc9a" : "#1f8a4c"

    // album-adaptive colour (set by Main.qml from the cover art); used by the immersive player
    // and by the "song" accent
    property color accent: "#d9d9d9"

    // how lyrics look (bound to session in Main.qml; see LyricLine.qml)
    property string lyricsSize: "medium"        // "small" | "medium" | "large"
    property string lyricsFont: "sans"          // "sans" | "serif"
    property string lyricsAlign: "left"         // "left" | "center"
    property string lyricsHighlight: "bright"   // "bright" | "glow" | "karaoke"
    readonly property real lyricsScale: lyricsSize === "small" ? 0.85 : lyricsSize === "large" ? 1.2 : 1
    readonly property bool lyricsSerif: lyricsFont === "serif"
    readonly property bool lyricsCentered: lyricsAlign === "center"

    readonly property int dockSpace: 32      // bottom padding of scrolling pages
    readonly property int sidebarWidth: 232
    readonly property int playerBarHeight: 88
    readonly property int rightPanelWidth: 340

    readonly property string font: "Google Sans Flex"
    readonly property string mono: "JetBrainsMono Nerd Font"

    function luma(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

    // a sharper copy of a cover for a big view: YouTube Music art `px` wide, and a music video's
    // still at full size (the 400×225 thumbnail YouTube lists songs with is far too small);
    // other art as it is. A video can lack the full size still: give the original as fallback.
    function hiRes(url, px) {
        url = String(url || "")
        const video = url.match(/^https?:\/\/i\.ytimg\.com\/vi\/([\w-]{11})\//)
        if (video)
            return "https://i.ytimg.com/vi/" + video[1] + "/maxresdefault.jpg"
        if (url.indexOf("googleusercontent.com") >= 0 || url.indexOf("ggpht.com") >= 0)
            return url.replace(/=w\d+-h\d+/, "=w" + px + "-h" + px).replace(/=s\d+/, "=s" + px)
        return url
    }

    function fmt(ms) {
        const total = Math.max(0, Math.floor((ms || 0) / 1000))
        const s = total % 60
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" : "") + s
    }

    function greeting() {
        const h = new Date().getHours()
        if (I18n.lang === "id")  // siang and sore have no separate English words
            return h < 11 ? "Selamat pagi" : h < 15 ? "Selamat siang" : h < 19 ? "Selamat sore" : "Selamat malam"
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
}
