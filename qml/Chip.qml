import QtQuick
import QtQuick.Controls

// Outlined pill for filters, tabs and small stats. `checked` = the selected tab.
AbstractButton {
    id: c
    property string iconName
    checkable: false
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 26
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        radius: height / 2
        color: c.checked ? Theme.selected : c.hovered ? Theme.subtle : "transparent"
        border.width: 1
        border.color: c.checked ? (Theme.accented ? Theme.alpha(Theme.primary, 0.7) : Theme.lineStrong) : c.hovered ? Theme.lineStrong : Theme.line
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Icon {
                visible: c.iconName !== ""
                glyph: c.iconName
                size: 15
                anchors.verticalCenter: parent.verticalCenter
                color: c.checked ? Theme.accentInk : c.hovered ? Theme.text : Theme.dim
            }
            Label {
                text: c.text
                font.pixelSize: 12
                font.weight: c.checked ? Font.Bold : Font.DemiBold
                color: c.checked ? Theme.accentInk : c.hovered ? Theme.text : Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
