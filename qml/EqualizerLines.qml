import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The equalizer as a column of fine lines (the poster and cinema full views): a line per band
// and one for the tempo, the value large on the right; drag along a line, double-click resets.
// Preset (click to go to the next one), on / off, and "keep original pitch" around them.
ColumnLayout {
    id: eql
    property color ink: "#ffffff"
    property color accent: Theme.accent
    property string family
    spacing: 0
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        Label {
            text: I18n.t("Equalizer").toUpperCase()
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 2.4
        }
        Item { Layout.fillWidth: true }
        LinkLabel {
            text: I18n.t(effects.preset) + "  ↻"
            color: eql.ink
            font.family: eql.family
            font.pixelSize: 15
            font.italic: true
            onClicked: effects.nextPreset()
        }
        LinkLabel {
            Layout.leftMargin: 16
            text: effects.enabled ? "ON" : "OFF"
            color: effects.enabled ? eql.accent : Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 1.5
            onClicked: effects.setEnabled(!effects.enabled)
        }
    }
    Repeater {
        model: 7   // six bands and the tempo
        Item {
            id: line
            required property int index
            readonly property bool isTempo: index === 6
            readonly property real value: isTempo ? effects.tempo : (effects.bands[index] || 0)
            // 0..1 along the line
            readonly property real frac: isTempo ? (value <= 1 ? value - 0.5 : 0.5 + (value - 1) / 2) : (value + 1) / 2
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            opacity: isTempo || effects.enabled ? 1 : 0.45
            Label {
                width: 90
                anchors.verticalCenter: parent.verticalCenter
                text: line.isTempo ? I18n.t("TEMPO") : effects.bandLabels[line.index] + " Hz"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
            Item {
                id: track
                x: 96
                width: parent.width - 96 - 96
                height: parent.height
                Rectangle { y: parent.height / 2; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.3) }
                Rectangle { x: parent.width / 2; y: parent.height / 2 - 6; width: 1; height: 12; color: Qt.rgba(1, 1, 1, 0.4) }
                Rectangle {
                    x: Math.min(parent.width / 2, line.frac * parent.width)
                    y: parent.height / 2 - 1
                    width: Math.abs(line.frac * parent.width - parent.width / 2)
                    height: 3
                    color: eql.accent
                }
                Rectangle {
                    x: line.frac * parent.width - width / 2
                    y: parent.height / 2 - height / 2
                    width: 12
                    height: 12
                    color: eql.ink
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    function set(mx) {
                        const f = Math.max(0, Math.min(1, mx / track.width))
                        if (line.isTempo) {
                            const t = f <= 0.5 ? 0.5 + f : 1 + (f - 0.5) * 2
                            effects.setTempo(Math.abs(t - 1) < 0.04 ? 1 : Math.round(t * 20) / 20)
                        } else {
                            effects.setBand(line.index, f * 2 - 1)
                        }
                    }
                    onPressed: (mouse) => set(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) set(mouse.x) }
                    onDoubleClicked: line.isTempo ? effects.setTempo(1) : effects.setBand(line.index, 0)
                }
            }
            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: line.isTempo ? line.value.toFixed(2) + "×"
                                   : (line.value >= 0 ? "+" : "") + (line.value * 12).toFixed(1)
                color: eql.ink
                font.family: eql.family
                font.pixelSize: 24
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }
        }
    }
    LinkLabel {
        Layout.topMargin: 12
        text: (effects.keepPitch ? "● " : "○ ") + I18n.t("Keep original pitch")
        color: effects.keepPitch ? eql.accent : Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: 13
        font.weight: Font.Bold
        onClicked: effects.setKeepPitch(!effects.keepPitch)
    }
    Item { Layout.fillHeight: true }
}
