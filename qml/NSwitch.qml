import QtQuick
import QtQuick.Controls

// On/off switch in the app's style: solid primary track when on.
Switch {
    id: sw
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    padding: 0
    spacing: 0
    implicitWidth: 42
    implicitHeight: 24

    indicator: Rectangle {
        width: 42
        height: 24
        radius: 12
        color: sw.checked ? Theme.primary : sw.hovered ? Theme.pressed : Theme.surface3
        border.width: sw.checked ? 0 : 1
        border.color: Theme.line
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            x: sw.checked ? parent.width - width - 4 : 4
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: sw.checked ? Theme.primaryText : Theme.dark ? "#d4d4d4" : "#ffffff"
            border.width: sw.checked || Theme.dark ? 0 : 1
            border.color: Theme.line
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Item {}
}
