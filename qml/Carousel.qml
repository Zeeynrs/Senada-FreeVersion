import QtQuick
import QtQuick.Controls

// Horizontal shelf of cards with a title and arrow buttons.
Column {
    id: c
    property string title
    property string subtitle
    property var items: []
    property real cardWidth: 188

    visible: items.length > 0
    spacing: 6

    Item {
        width: parent.width
        height: c.title !== "" ? 44 : 8
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: c.title !== ""
            Label { text: c.title; font.pixelSize: 18; font.weight: Font.Bold }
            Label { visible: c.subtitle !== ""; text: c.subtitle; color: Theme.dim; font.pixelSize: 13 }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: list.contentWidth > list.width
            IconButton {
                iconName: "back"; size: 18; tint: Theme.dim
                enabled: !list.atXBeginning
                tip: I18n.t("Scroll left")
                onClicked: list.flickTo(-1)
            }
            IconButton {
                iconName: "back"; size: 18; tint: Theme.dim
                rotation: 180
                enabled: !list.atXEnd
                tip: I18n.t("Scroll right")
                onClicked: list.flickTo(1)
            }
        }
    }

    ListView {
        id: list
        width: parent.width
        height: contentItem.childrenRect.height > 0 ? contentItem.childrenRect.height : c.cardWidth + 70
        orientation: ListView.Horizontal
        clip: true
        spacing: 4
        model: c.items
        boundsBehavior: Flickable.StopAtBounds
        // not draggable/wheelable itself, so a vertical wheel keeps scrolling the page;
        // arrows and horizontal touchpad swipes move the shelf instead
        interactive: false
        cacheBuffer: 600
        delegate: Card { width: c.cardWidth; item: modelData }

        function flickTo(dir) {
            const target = Math.max(0, Math.min(contentWidth - width, contentX + dir * width * 0.8))
            scrollAnim.to = target
            scrollAnim.restart()
        }
        NumberAnimation { id: scrollAnim; target: list; property: "contentX"; duration: 420; easing.type: Easing.OutCubic }
        // vertical wheel scrolls the page, horizontal wheel/touchpad scrolls the shelf
        WheelHandler {
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            orientation: Qt.Horizontal
            onWheel: (e) => list.contentX = Math.max(0, Math.min(list.contentWidth - list.width, list.contentX - e.angleDelta.x))
        }
    }
}
