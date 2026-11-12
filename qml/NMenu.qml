import QtQuick
import QtQuick.Controls

Menu {
    id: m
    padding: 6
    background: Rectangle {
        implicitWidth: 230
        color: Theme.surface2
        radius: 12
        border.color: Theme.line
    }
    delegate: MenuItem {
        id: mi
        implicitHeight: 36
        contentItem: Label {
            text: mi.text
            font.pixelSize: 13
            color: mi.enabled ? Theme.text : Theme.faint
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: mi.highlighted ? Theme.hover : "transparent"
        }
    }
}
