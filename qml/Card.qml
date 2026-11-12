import QtQuick
import QtQuick.Controls

// Library/catalog tile. Each kind has its own silhouette:
//   artist   -> scalloped (bloom) avatar
//   album    -> square cover with a vinyl disc that slides out on hover
//   playlist -> cover on a small stack of sheets
Item {
    id: card
    property var item: ({})
    readonly property string kind: item.kind || ""
    readonly property bool isArtist: kind === "artist"
    readonly property bool isAlbum: kind === "album"
    readonly property bool isPlaylist: kind === "playlist"
    readonly property real side: width - 24

    implicitHeight: col.implicitHeight + 24

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    // a MouseArea (not TapHandler) so clicks on the play button don't also navigate
    MouseArea { anchors.fill: parent; onClicked: Nav.go(card.item.kind, card.item.id) }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: hover.hovered ? Theme.glass : "transparent"
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Column {
        id: col
        x: 12; y: 12
        width: card.side
        spacing: 4

        Item {
            width: parent.width
            height: width

            // playlist: two sheets peeking out above the cover
            Rectangle {
                visible: card.isPlaylist
                x: parent.width * 0.12; width: parent.width * 0.76
                y: -10; height: parent.height
                radius: 18
                color: Theme.alpha(Theme.text, 0.06)
            }
            Rectangle {
                visible: card.isPlaylist
                x: parent.width * 0.06; width: parent.width * 0.88
                y: -5; height: parent.height
                radius: 18
                color: Theme.alpha(Theme.text, 0.10)
            }

            // album: vinyl disc behind the cover
            Item {
                id: disc
                visible: card.isAlbum
                width: parent.width * 0.92; height: width
                anchors.verticalCenter: parent.verticalCenter
                x: hover.hovered ? parent.width * 0.2 : parent.width * 0.04
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Rectangle { anchors.fill: parent; radius: width / 2; color: "#07090c"; border.color: Qt.rgba(1, 1, 1, 0.08) }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.7; height: width; radius: width / 2; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.05) }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.32; height: width; radius: width / 2; color: Theme.mint }
                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "#07090c" }
            }

            Cover {
                anchors.fill: parent
                source: card.item.image || card.item.imageSmall || ""
                scalloped: card.isArtist
                scallops: 16
                scallopDepth: 0.045
                radius: 18
                fallbackIcon: card.isArtist ? "speaker" : "note"
                scale: hover.hovered && !card.isAlbum ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            BloomPlayButton {
                size: 46
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: card.isArtist ? 2 : 10
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0 && !!card.item.uri
                tip: "Putar"
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onClicked: player.playContext(card.item.uri, "")
            }
        }
        Item { width: 1; height: 8 }
        Label {
            width: parent.width
            text: card.item.name || ""
            elide: Text.ElideRight
            font.pixelSize: 15
            font.weight: Font.DemiBold
            horizontalAlignment: card.isArtist ? Text.AlignHCenter : Text.AlignLeft
        }
        Label {
            width: parent.width
            text: card.isAlbum && card.item.year ? card.item.year + " • " + card.item.subtitle : (card.item.subtitle || "")
            elide: Text.ElideRight
            color: Theme.dim
            font.pixelSize: 13
            horizontalAlignment: card.isArtist ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
