import QtQuick
import QtQuick.Controls

TextField {
    id: f
    property string iconName

    implicitHeight: 44
    leftPadding: iconName ? 44 : 18
    rightPadding: 18
    font.pixelSize: 15
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.alpha(Theme.mint, 0.4)
    selectedTextColor: Theme.text

    background: Rectangle {
        radius: height / 2
        color: f.activeFocus ? Theme.glassStrong : f.hovered ? Theme.glassHover : Theme.glass
        border.width: f.activeFocus ? 2 : 1
        border.color: f.activeFocus ? Theme.alpha(Theme.mint, 0.75) : Theme.glassBorder
        Icon {
            visible: f.iconName !== ""
            glyph: f.iconName
            size: 20
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
            x: 14
        }
    }
}
