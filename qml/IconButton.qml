import QtQuick
import QtQuick.Controls

// Round icon button. `filled` = solid primary (white on dark, black on light),
// `outlined` = thin ring, `active` = toggled on (shuffle, repeat, …).
AbstractButton {
    id: b
    property string iconName
    property int size: 20
    property bool active: false
    property bool filled: false
    property bool outlined: false
    property color tint: palette.windowText
    readonly property color ink: palette.windowText  // Theme.text, or light inside the immersive view
    property string tip

    implicitWidth: size + (filled ? 24 : 16)
    implicitHeight: implicitWidth
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: height / 2
        color: b.filled ? (b.down ? Theme.alpha(b.ink, 0.8) : b.ink)
                        : b.down ? Theme.alpha(b.ink, 0.13) : b.hovered ? Theme.alpha(b.ink, 0.08) : "transparent"
        border.width: b.outlined && !b.filled ? 1 : 0
        border.color: Theme.alpha(b.ink, b.hovered ? 0.55 : 0.13)
        scale: b.filled && b.hovered ? 1.05 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            glyph: b.iconName
            size: b.size
            color: b.filled ? b.palette.window : b.active ? b.ink : b.tint
        }
        Rectangle {
            visible: b.active && !b.filled
            implicitWidth: 4; implicitHeight: 4; radius: 2
            color: b.ink
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -1
        }
    }

    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 600
}
