import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// A ruled paper card, slightly askew, with a red margin line and a handwritten title: the
// cassette full view writes its lyrics and its track list on these. Content goes below the
// title (children), starting right of the margin line at `textX`.
Item {
    id: card
    property string title
    property string handFont
    default property alias content: body.data
    readonly property real textX: 56
    readonly property color ink: "#26262e"
    rotation: 1.2

    Rectangle {
        id: paperShape
        anchors.fill: parent
        radius: 6
        color: "#f4efe2"
        visible: false
    }
    MultiEffect {
        anchors.fill: paperShape
        source: paperShape
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.55
        shadowBlur: 0.8
        shadowVerticalOffset: 10
    }
    Rectangle {  // the paper
        anchors.fill: parent
        radius: 6
        color: "#f4efe2"
        // margin line, like a notebook
        Rectangle { x: 44; y: 0; width: 1.5; height: parent.height; color: Qt.rgba(0.85, 0.3, 0.3, 0.45) }
    }
    Label {
        id: titleLabel
        x: card.textX
        y: 16
        width: parent.width - card.textX - 16
        text: card.title
        font.family: card.handFont
        font.pixelSize: 18
        font.weight: Font.Bold
        color: Qt.rgba(0.15, 0.15, 0.19, 0.7)
        elide: Text.ElideRight
    }
    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
    }
}
