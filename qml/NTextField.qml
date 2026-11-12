import QtQuick
import QtQuick.Controls

TextField {
    id: f
    property string iconName

    implicitHeight: 42
    leftPadding: iconName ? 42 : 16
    rightPadding: 16
    font.pixelSize: 14
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.alpha(Theme.primary, 0.3)
    selectedTextColor: Theme.text

    background: Rectangle {
        radius: 12
        color: f.activeFocus ? Theme.surface : f.hovered ? Theme.hover : Theme.subtle
        border.width: 1
        border.color: f.activeFocus ? Theme.lineStrong : Theme.line
        Icon {
            visible: f.iconName !== ""
            glyph: f.iconName
            size: 18
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
            x: 14
        }
    }
}
