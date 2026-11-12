import QtQuick
import QtQuick.Controls

Rectangle {
    id: t
    property bool shown: false

    function show(msg) {
        label.text = msg
        shown = true
        hideTimer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    y: shown ? parent.height - height - Theme.dockSpace : parent.height + 10
    z: 1000
    width: Math.min(label.implicitWidth + 64, parent.width - 48)
    height: 44
    radius: 22
    color: Theme.surface2
    border.color: Theme.alpha(Theme.mint, 0.35)
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Scallop {
        width: 14; height: 14
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        lobes: 8; depth: 0.14
        color: Theme.mint
    }
    Label {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 10
        width: Math.min(implicitWidth, t.width - 64)
        elide: Text.ElideRight
        font.pixelSize: 14
    }
    Timer { id: hideTimer; interval: 3200; onTriggered: t.shown = false }
    MouseArea { anchors.fill: parent; onClicked: t.shown = false }
}
