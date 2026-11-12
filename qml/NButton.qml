import QtQuick
import QtQuick.Controls

// Pill button: mint when `primary`, frosted glass otherwise.
AbstractButton {
    id: b
    property bool primary: false
    property string iconName

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 32
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.4

    background: Rectangle {
        radius: height / 2
        color: b.primary ? (b.down ? Qt.darker(Theme.mint, 1.12) : b.hovered ? Qt.lighter(Theme.mint, 1.06) : Theme.mint)
                         : (b.down ? Theme.glassStrong : b.hovered ? Theme.glassHover : Theme.glass)
        border.width: b.primary ? 0 : 1
        border.color: Theme.glassBorder
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
                size: 18
                anchors.verticalCenter: parent.verticalCenter
                color: b.primary ? Theme.primaryText : Theme.text
            }
            Label {
                text: b.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: b.primary ? Theme.primaryText : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
