import QtQuick
import QtQuick.Controls.impl

// The Senada mark in one colour, or as a left-to-right gradient when given several
// colours (drawn as thin tinted slices, so it needs no shader and works everywhere).
Item {
    id: lm
    property var colors: [Theme.primary]
    property int size: 24
    readonly property int slices: colors.length > 1 ? 24 : 1

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    function colorAt(t) {
        const n = colors.length
        if (n === 0) return Theme.text
        if (n === 1) return colors[0]
        const pos = t * (n - 1)
        const i = Math.min(n - 2, Math.floor(pos))
        return Theme.mix(Qt.color(colors[i]), Qt.color(colors[i + 1]), pos - i)
    }

    Repeater {
        model: lm.slices
        Item {
            required property int index
            x: Math.floor(index * lm.width / lm.slices)
            width: Math.ceil(lm.width / lm.slices) + 1
            height: lm.height
            clip: lm.slices > 1
            IconImage {
                x: -parent.x
                width: lm.width
                height: lm.height
                source: Qt.resolvedUrl("icons/logo.png")
                sourceSize: Qt.size(lm.size * 2, lm.size * 2)
                color: lm.colorAt(lm.slices > 1 ? index / (lm.slices - 1) : 0)
            }
        }
    }
}
