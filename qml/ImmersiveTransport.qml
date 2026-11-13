import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shuffle, previous, round white play / pause, next and repeat for the full view.
Row {
    id: tr
    property int playSize: 62   // the round white play / pause button
    readonly property var s: player ? player.state : ({})
    spacing: 22

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "shuffle"
        size: 20
        active: !!tr.s.shuffle
        tip: I18n.t("Shuffle")
        onClicked: player.toggleShuffle()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "previous"
        size: 22
        tip: I18n.t("Previous (Ctrl+←)")
        onClicked: player.previous()
    }

    // round white play / pause button
    Rectangle {
        width: tr.playSize
        height: tr.playSize
        radius: tr.playSize / 2
        anchors.verticalCenter: parent.verticalCenter
        color: "#ffffff"
        scale: playMouse.pressed ? 0.94 : (playMouse.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Icon {
            anchors.centerIn: parent
            glyph: tr.s.isPlaying ? "pause" : "play"
            size: Math.round(tr.playSize * 0.42)
            color: "#111111"
        }
        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: player.togglePlay()
        }
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "next"
        size: 22
        tip: I18n.t("Next (Ctrl+→)")
        onClicked: player.next()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: tr.s.repeat === "track" ? "repeat-one" : "repeat"
        size: 20
        active: tr.s.repeat !== undefined && tr.s.repeat !== "off"
        tip: I18n.t("Repeat")
        onClicked: player.cycleRepeat()
    }
}
