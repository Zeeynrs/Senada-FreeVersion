import QtQuick
import QtQuick.Controls

Slider {
    id: c
    property color fill: Theme.accented ? Theme.primary : palette.windowText
    readonly property bool engaged: hovered || pressed

    implicitHeight: 20
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        x: c.leftPadding
        y: c.topPadding + c.availableHeight / 2 - height / 2
        width: c.availableWidth
        height: c.engaged ? 6 : 4
        radius: height / 2
        color: Theme.alpha(c.palette.windowText, 0.16)
        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
            width: c.visualPosition * parent.width
            height: parent.height
            radius: height / 2
            color: c.fill
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    handle: Rectangle {
        x: c.leftPadding + c.visualPosition * (c.availableWidth - width)
        y: c.topPadding + c.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: c.palette.windowText
        opacity: c.engaged ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
