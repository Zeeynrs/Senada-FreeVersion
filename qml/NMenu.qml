import QtQuick
import QtQuick.Controls

Menu {
    id: m
    padding: 6
    background: Rectangle {
        implicitWidth: 230
        color: Theme.surface2
        radius: 18
        border.color: Theme.glassBorder
    }
    delegate: MenuItem {
        id: mi
        implicitHeight: 38
        contentItem: Label {
            text: mi.text
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 12
            color: mi.highlighted ? Theme.alpha(Theme.mint, 0.14) : "transparent"
        }
    }
}
