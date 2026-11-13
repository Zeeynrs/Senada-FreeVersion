import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Seek bar of the full view: elapsed time, a white bar that thickens on hover, "-remaining".
RowLayout {
    id: seekRow
    readonly property var s: player ? player.state : ({})
    spacing: 10

    readonly property real durationMs: Math.max(1, seekRow.s.durationMs || 0)
    readonly property real currentMs: seekMouse.pressed ? seekMouse.dragMs : (player ? player.position : 0)
    readonly property real progress: Math.max(0, Math.min(1, currentMs / durationMs))

    Label {
        text: Theme.fmt(seekRow.currentMs)
        color: Qt.rgba(1, 1, 1, 0.72)
        font.pixelSize: 11
        font.features: { "tnum": 1 }
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
    }

    Item {
        id: seekTrack
        Layout.fillWidth: true
        height: 22
        readonly property bool engaged: seekMouse.containsMouse || seekMouse.pressed

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: seekTrack.engaged ? 6 : 4
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on height { NumberAnimation { duration: 120 } }
            Rectangle {
                width: seekRow.progress * parent.width
                height: parent.height
                radius: height / 2
                color: "#ffffff"
            }
        }
        Rectangle {  // thumb
            width: seekTrack.engaged ? 14 : 0
            height: width
            radius: width / 2
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: seekRow.progress * parent.width - width / 2
            Behavior on width { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: seekMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !!seekRow.s.hasTrack
            property real dragMs: 0
            function updateDrag(mx) {
                const n = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                dragMs = n * seekRow.durationMs
            }
            onPressed: (mouse) => updateDrag(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) updateDrag(mouse.x) }
            onReleased: player.seek(dragMs)
        }
    }

    Label {
        text: "-" + Theme.fmt(Math.max(0, (seekRow.s.durationMs || 0) - seekRow.currentMs))
        color: Qt.rgba(1, 1, 1, 0.72)
        font.pixelSize: 11
        font.features: { "tnum": 1 }
        Layout.preferredWidth: 38
    }
}
