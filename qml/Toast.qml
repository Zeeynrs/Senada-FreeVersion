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
    y: shown ? parent.height - height - Theme.playerBarHeight - 18 : parent.height + 10
    z: 1000
    width: Math.min(label.implicitWidth + 40, parent.width - 48)
    height: 40
    radius: 20
    color: Theme.primary
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Label {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, t.width - 40)
        elide: Text.ElideRight
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.primaryText
    }
    Timer { id: hideTimer; interval: 3200; onTriggered: t.shown = false }
    MouseArea { anchors.fill: parent; onClicked: t.shown = false }
}
