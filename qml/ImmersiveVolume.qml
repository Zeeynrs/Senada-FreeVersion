import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Volume of the full view: mute toggle and a white bar (scroll to change).
RowLayout {
    id: volRow
    readonly property var s: player ? player.state : ({})
    spacing: 12
    property int lastVol: 60
    readonly property int vol: (volRow.s.volume !== undefined && volRow.s.volume >= 0) ? volRow.s.volume : 80

    Icon {
        glyph: volRow.vol === 0 ? "volume-off" : "volume"
        size: 16
        color: Qt.rgba(1, 1, 1, 0.72)
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (volRow.vol > 0) {
                    volRow.lastVol = volRow.vol
                    player.setVolume(0)
                } else {
                    player.setVolume(volRow.lastVol || 60)
                }
            }
        }
    }

    Item {
        id: volBar
        Layout.fillWidth: true
        height: 20
        readonly property real norm: Math.max(0, Math.min(1, volRow.vol / 100))

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.22)

            Rectangle {
                width: volBar.norm * parent.width
                height: parent.height
                radius: 2
                color: "#ffffff"
            }
        }

        Rectangle {  // thumb
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, volBar.norm * parent.width - width / 2))
            color: "#ffffff"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function setFromX(mx) {
                const pct = Math.round(Math.max(0, Math.min(1, mx / Math.max(1, width))) * 100)
                player.setVolume(pct)
            }
            onPressed: (mouse) => setFromX(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
            onWheel: (wheel) => player.setVolume(Math.max(0, Math.min(100, volRow.vol + (wheel.angleDelta.y > 0 ? 5 : -5))))
        }
    }
}
