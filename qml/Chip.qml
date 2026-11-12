import QtQuick
import QtQuick.Controls

// Pill-shaped toggle/filter chip. `checked` fills it with mint.
AbstractButton {
    id: c
    property string iconName
    checkable: false
    implicitHeight: 36
    implicitWidth: row.implicitWidth + 28
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        radius: height / 2
        color: c.checked ? Theme.mint : c.hovered ? Theme.glassHover : Theme.glass
        border.width: c.checked ? 0 : 1
        border.color: Theme.glassBorder
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Icon {
                visible: c.iconName !== ""
                glyph: c.iconName
                size: 16
                anchors.verticalCenter: parent.verticalCenter
                color: c.checked ? Theme.primaryText : Theme.text
            }
            Label {
                text: c.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: c.checked ? Theme.primaryText : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
