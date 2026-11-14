import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// One line of lyrics drawn the way Settings → Lyrics → Appearance says (Theme.lyrics*): its
// size, font and alignment, and how the sung line stands out: "bright" (only brighter),
// "glow" (a soft light around it) or "karaoke" (filled in while it is sung: word by word with
// the singer when the lyrics are timed per word, otherwise evenly up to where the next line
// starts). Used by the lyric lists: the side panel, the visualizer full view and the open mini player.
Label {
    id: ll
    property var line: ({})          // { t: start in ms, text, words?: [{ t, d, text }] } (senada/lyrics.py)
    property real nextT: -1          // when the next line starts (karaoke fills up until then)
    property bool current: false
    property bool past: false
    property bool synced: true
    property real baseSize: 20
    property color activeColor: "#ffffff"
    property color restColor: Qt.rgba(1, 1, 1, 0.36)
    property color pastColor: restColor
    // karaoke: the part of the sung line still to come (default: a dim copy of activeColor, for a
    // dark background); glow: how strong the light is (lower it on a light background)
    property color unsungColor: Qt.rgba(activeColor.r * 0.45, activeColor.g * 0.45, activeColor.b * 0.45, 1)
    property real glowOpacity: 0.85
    property real position: player ? player.position : 0   // the preview in Settings plays its own clock

    readonly property string plain: (line && line.text) || "♪"
    readonly property bool karaoke: Theme.lyricsHighlight === "karaoke" && current && synced
    readonly property var words: (line && line.words) || []
    // how many letters of the line are sung: the words already over, and the one being sung
    // so far; without word timing, an even share of the time until the next line
    readonly property int sungLetters: {
        if (!karaoke)
            return 0
        if (words.length > 0) {
            let n = 0
            for (let i = 0; i < words.length; i++) {
                const w = words[i]
                if (position >= w.t + w.d) {
                    n += w.text.length
                    continue
                }
                if (position > w.t && w.d > 0)
                    n += Math.round(w.text.replace(/\s+$/, "").length * (position - w.t) / w.d)
                break
            }
            return n
        }
        const start = line.t || 0
        const end = nextT > start ? nextT : start + 4000
        return Math.round(plain.length * Math.max(0, Math.min(1, (position - start) / (end - start))))
    }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function hex(c) {   // #rrggbb for rich text (an alpha would be read as part of the colour)
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
    // karaoke: the part already sung in full colour, the rest a dim version of the same colour
    readonly property string sungSoFar: {
        const n = sungLetters
        return '<font color="' + hex(activeColor) + '">' + esc(plain.slice(0, n)) + '</font>'
             + '<font color="' + hex(unsungColor) + '">' + esc(plain.slice(n)) + '</font>'
    }

    text: karaoke ? sungSoFar : plain
    textFormat: karaoke ? Text.StyledText : Text.PlainText
    wrapMode: Text.WordWrap
    color: current ? activeColor : past ? pastColor : restColor
    font.pixelSize: Math.round(baseSize * Theme.lyricsScale)
    font.family: Theme.lyricsSerif ? "Georgia" : Qt.application.font.family
    horizontalAlignment: Theme.lyricsCentered ? Text.AlignHCenter : Text.AlignLeft

    // glow: a soft light of the accent (white without one) around the sung line
    layer.enabled: Theme.lyricsHighlight === "glow" && current && synced
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.accented ? Theme.primary : "#ffffff"
        shadowBlur: 0.9
        shadowOpacity: ll.glowOpacity
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 24
    }
}
