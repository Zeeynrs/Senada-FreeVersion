import QtQuick
import QtQuick.Controls

// Pill button: solid primary when `primary`, outlined otherwise.
AbstractButton {
    id: b
    property bool primary: false
    property string iconName

    implicitHeight: 38
    implicitWidth: row.implicitWidth + 30
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    background: Rectangle {
        radius: height / 2
        color: b.primary ? (b.down ? Theme.alpha(Theme.primary, 0.8) : b.hovered ? Theme.alpha(Theme.primary, 0.9) : Theme.primary)
                         : (b.down ? Theme.pressed : b.hovered ? Theme.hover : "transparent")
        border.width: b.primary && !b.visualFocus ? 0 : 1
        border.color: b.visualFocus || b.hovered ? Theme.lineStrong : Theme.line
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Icon {
                visible: b.iconName !== ""
                glyph: b.iconName
                size: 17
                anchors.verticalCenter: parent.verticalCenter
                color: b.primary ? Theme.primaryText : Theme.text
            }
            Label {
                text: b.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: b.primary ? Theme.primaryText : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
