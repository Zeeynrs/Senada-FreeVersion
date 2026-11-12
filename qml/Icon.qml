import QtQuick
import QtQuick.Controls.impl

// Monochrome SVG icon from qml/icons, tinted with `color`. Wrapped in an Item so
// layouts see `size` as its implicit size (not the doubled source size).
Item {
    id: root
    property string glyph
    property int size: 20
    property color color: palette.windowText  // inherited: Theme.text in the app, light in the immersive view

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    IconImage {
        anchors.fill: parent
        source: root.glyph ? Qt.resolvedUrl("icons/" + root.glyph + ".svg") : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        color: root.color
    }
}
