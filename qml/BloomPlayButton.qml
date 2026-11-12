import QtQuick
import QtQuick.Controls

// Mint scalloped play/pause button; the petals slowly turn while music plays.
AbstractButton {
    id: b
    property bool playing: false
    property int size: 52
    property color fill: Theme.mint
    property color iconColor: Theme.primaryText
    property string tip: playing ? "Jeda (Spasi)" : "Putar (Spasi)"

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.4
    scale: down ? 0.93 : hovered ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    background: Scallop {
        id: petals
        color: b.hovered ? Qt.lighter(b.fill, 1.06) : b.fill
        lobes: 12
        depth: 0.07
        // turn the whole shape (a cheap GPU transform) instead of repainting the canvas
        NumberAnimation on rotation {
            running: b.playing && b.visible
            from: 0; to: 360 / 12
            duration: 2600
            loops: Animation.Infinite
        }
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: b.playing ? 0 : 1
            glyph: b.playing ? "pause" : "play"
            size: Math.round(b.size * 0.42)
            color: b.iconColor
        }
    }

    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 600
}
