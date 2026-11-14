import QtQuick
import QtQuick.Controls

// Volume as a slim upright rail along the right edge of the vinyl, poster and cinema full views:
// the level on top, the bar in the middle (drag it or scroll anywhere on the rail), and the
// speaker at the bottom to mute and unmute. It widens while the pointer is on it.
Item {
    id: rail
    readonly property var s: player ? player.state : ({})
    readonly property int vol: (s.volume !== undefined && s.volume >= 0) ? s.volume : 80
    readonly property real norm: Math.max(0, Math.min(1, vol / 100))
    readonly property bool engaged: hover.hovered || drag.pressed
    property int lastVol: 60
    implicitWidth: 40
    implicitHeight: 260

    HoverHandler { id: hover }

    Label {
        id: level
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: rail.vol
        color: Qt.rgba(1, 1, 1, rail.engaged ? 0.95 : 0.55)
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Item {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: level.bottom
        anchors.topMargin: 12
        anchors.bottom: speaker.top
        anchors.bottomMargin: 14
        width: parent.width

        Rectangle {  // the groove
            anchors.horizontalCenter: parent.horizontalCenter
            width: rail.engaged ? 6 : 4
            height: parent.height
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on width { NumberAnimation { duration: 140 } }
            Rectangle {  // the level, filled from the bottom
                anchors.bottom: parent.bottom
                width: parent.width
                height: rail.norm * parent.height
                radius: width / 2
                color: "#ffffff"
            }
        }
        Rectangle {  // thumb
            anchors.horizontalCenter: parent.horizontalCenter
            width: rail.engaged ? 14 : 12
            height: width
            radius: width / 2
            y: Math.max(0, Math.min(track.height - height, (1 - rail.norm) * track.height - height / 2))
            color: "#ffffff"
            Behavior on width { NumberAnimation { duration: 140 } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function setFromY(my) {
                const f = 1 - (my - 6) / Math.max(1, track.height)
                player.setVolume(Math.round(Math.max(0, Math.min(1, f)) * 100))
            }
            onPressed: (mouse) => setFromY(mouse.y)
            onPositionChanged: (mouse) => { if (pressed) setFromY(mouse.y) }
        }
    }

    Icon {
        id: speaker
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        glyph: rail.vol === 0 ? "volume-off" : "volume"
        size: 18
        color: Qt.rgba(1, 1, 1, rail.engaged ? 0.95 : 0.65)
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (rail.vol > 0) {
                    rail.lastVol = rail.vol
                    player.setVolume(0)
                } else {
                    player.setVolume(rail.lastVol || 60)
                }
            }
        }
        ToolTip.visible: speakerTip.hovered
        ToolTip.text: rail.vol === 0 ? I18n.t("Unmute") : I18n.t("Mute")
        ToolTip.delay: 400
        HoverHandler { id: speakerTip }
    }

    // scroll anywhere on the rail
    WheelHandler {
        onWheel: (event) => player.setVolume(Math.max(0, Math.min(100, rail.vol + (event.angleDelta.y > 0 ? 5 : -5))))
    }
}
