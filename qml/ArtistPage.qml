import QtQuick
import QtQuick.Controls

Item {
    id: page
    property string itemId
    readonly property string pageKey: "artist:" + itemId
    property var info: ({})
    property bool loading: true

    Component.onCompleted: library.load("artist", itemId)
    Connections {
        target: library
        function onLoaded(key, data) {
            if (key !== page.pageKey) return
            page.info = data
            page.loading = false
            Qt.callLater(list.positionViewAtBeginning)  // the header grew; show it from the top
            if (data.error) session.toast(data.error)
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        currentIndex: -1  // don't auto-scroll to the first row (it would clip the header)
        model: page.info.tracks || []
        bottomMargin: Theme.dockSpace
        ScrollBar.vertical: NScrollBar {}

        header: Column {
            width: list.width
            PageHeader {
                width: parent.width
                info: page.info
                loading: page.loading
                round: true
                fallbackIcon: "speaker"
                canSave: !page.info.error
                saved: (library.savedRevision, library.isSaved("artist", page.itemId))
                onPlayAll: player.playContext(page.info.playUri || page.info.uri, "")
                onShuffleAll: player.shufflePlay(page.info.playUri || page.info.uri)
                onSaveToggled: library.toggleSaved(page.info)
            }
            Label {
                visible: (page.info.tracks || []).length > 0
                text: "Lagu teratas"
                font.pixelSize: 22
                font.weight: Font.Bold
                leftPadding: 32
                bottomPadding: 8
            }
        }

        delegate: TrackRow {
            track: modelData
            number: index + 1
            showAlbum: true
            onPlay: player.playUris((page.info.tracks || []).map(x => x.uri), index)
        }

        footer: Column {
            width: list.width
            topPadding: 24
            bottomPadding: 16
            spacing: 24
            CardGrid {
                x: 20
                width: parent.width - 40
                title: "Diskografi"
                items: page.info.albums || []
                rows: 2
            }
            Repeater {
                model: page.info.sections || []
                CardGrid {
                    x: 20
                    width: list.width - 40
                    title: modelData.title
                    items: modelData.cards || []
                    rows: 1
                }
            }
        }
    }
}
