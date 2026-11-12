import QtQuick
import QtQuick.Controls

// Album / playlist / artist tile: an outlined card with the cover, a save heart in the
// top-left corner and a play button in the bottom-right corner of the cover.
Item {
    id: card
    property var item: ({})
    readonly property string kind: item.kind || ""
    readonly property bool isArtist: kind === "artist"
    readonly property bool canSave: !!item.id && (item.id + "").indexOf("local-") !== 0
                                    && (kind === "album" || kind === "playlist" || kind === "artist")
    readonly property bool saved: (library.savedRevision, canSave && library.isSaved(kind, item.id || ""))
    readonly property real side: width - 24

    implicitHeight: col.implicitHeight + 26

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    // a MouseArea (not TapHandler) so clicks on the inner buttons don't also navigate
    MouseArea { anchors.fill: parent; onClicked: Nav.go(card.item.kind, card.item.id) }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 16
        color: hover.hovered ? Theme.hover : "transparent"
        border.color: hover.hovered ? Theme.lineStrong : Theme.line
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Column {
        id: col
        x: 12; y: 12
        width: card.side
        spacing: 3

        Item {
            width: parent.width
            height: width

            Cover {
                anchors.fill: parent
                source: card.item.image || card.item.imageSmall || ""
                round: card.isArtist
                radius: 10
                fallbackIcon: card.isArtist ? "person" : card.kind === "album" ? "album" : "note"
            }

            // save to the library
            AbstractButton {
                id: saveBtn
                visible: card.canSave && (hover.hovered || card.saved)
                x: card.isArtist ? parent.width * 0.08 : 8
                y: card.isArtist ? parent.height * 0.04 : 8
                implicitWidth: 30; implicitHeight: 30
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                onClicked: library.toggleSaved(card.item)
                background: Rectangle {
                    radius: 15
                    color: saveBtn.hovered ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.55)
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        glyph: card.saved ? "heart" : "heart-outline"
                        size: 16
                        color: card.saved ? Theme.like : "#ffffff"
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: card.saved ? I18n.t("Remove from Library") : I18n.t("Save to Library")
                ToolTip.delay: 500
            }

            // play
            AbstractButton {
                id: playBtn
                visible: !!card.item.uri && hover.hovered
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: card.isArtist ? parent.width * 0.04 : 8
                implicitWidth: 40; implicitHeight: 40
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                onClicked: player.playContext(card.item.uri, "")
                background: Rectangle {
                    radius: 20
                    color: playBtn.hovered ? "#ffffff" : Qt.rgba(0, 0, 0, 0.7)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        glyph: "play"
                        size: 20
                        color: playBtn.hovered ? "#000000" : "#ffffff"
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: I18n.t("Play")
                ToolTip.delay: 500
            }
        }
        Item { width: 1; height: 8 }
        Label {
            width: parent.width
            text: card.item.name || ""
            elide: Text.ElideRight
            font.pixelSize: 14
            font.weight: Font.Bold
            horizontalAlignment: card.isArtist ? Text.AlignHCenter : Text.AlignLeft
        }
        Label {
            width: parent.width
            text: card.kind === "album" && card.item.year ? card.item.year + " • " + card.item.subtitle : (card.item.subtitle || "")
            elide: Text.ElideRight
            color: Theme.dim
            font.pixelSize: 12
            horizontalAlignment: card.isArtist ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
