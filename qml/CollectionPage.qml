import QtQuick
import QtQuick.Controls

// Playlist, album and liked songs.
Item {
    id: page
    property string kind
    property string itemId
    readonly property string pageKey: kind + ":" + itemId
    property var info: ({})
    property bool loading: true

    function reload() {
        loading = true
        library.load(kind, itemId)
    }
    Component.onCompleted: reload()

    readonly property bool isLocal: !!info.local
    readonly property bool isSpotify: itemId.indexOf("sp-") === 0

    Connections {
        target: library
        function onLoaded(key, data) {
            if (key !== page.pageKey) return
            page.info = data
            page.loading = false
            Qt.callLater(list.positionViewAtBeginning)  // the header grew; show it from the top
            if (data.error) session.toast(data.error)
        }
        // keep liked songs and own playlists in sync with edits made elsewhere
        function onLikedChanged() { if (page.kind === "liked") library.load(page.kind, page.itemId) }
        function onPlaylistsChanged() {
            if (page.isLocal && library.ownPlaylists.some(p => p.id === page.itemId))
                library.load(page.kind, page.itemId)
        }
    }

    function playAt(i) {
        const t = info.tracks || []
        if (info.playUri)
            player.playContext(info.playUri, t[i] ? t[i].uri : "")
        else
            player.playUris(t.map(x => x.uri), i)
    }
    function playAll() { playAt(0) }
    function shuffleAll() {
        if (info.playUri) {
            player.shufflePlay(info.playUri)
            return
        }
        const uris = (info.tracks || []).map(x => x.uri)
        for (let i = uris.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [uris[i], uris[j]] = [uris[j], uris[i]]
        }
        player.playUris(uris, 0)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        currentIndex: -1  // don't auto-scroll to the first row (it would clip the header)
        model: page.info.tracks || []
        reuseItems: true
        bottomMargin: Theme.dockSpace
        ScrollBar.vertical: NScrollBar {}

        header: PageHeader {
            width: list.width
            info: page.info
            loading: page.loading
            fallbackIcon: page.kind === "liked" ? "heart" : "note"
            canSave: page.kind !== "liked" && !page.isLocal && !page.isSpotify && !page.info.error
            saved: (library.savedRevision, library.isSaved(page.kind, page.itemId))
            canImport: page.isSpotify && (page.info.tracks || []).length > 0
            isLocal: page.isLocal
            onPlayAll: page.playAll()
            onShuffleAll: page.shuffleAll()
            onSaveToggled: library.toggleSaved(page.info)
            onImportRequested: library.importCollection(page.info)
            onRenameRequested: Nav.renamePlaylist(page.itemId, page.info.name)
            onDeleteRequested: Nav.deletePlaylist(page.itemId, page.info.name)
        }

        delegate: TrackRow {
            track: modelData
            number: index + 1
            showCover: page.kind !== "album"
            showAlbum: page.kind !== "album"
            removable: page.isLocal
            onPlay: page.playAt(index)
            onRemove: library.removeFromPlaylist(page.itemId, modelData.uri)
        }

        footer: Label {
            width: list.width
            visible: !!page.info.note
            text: page.info.note || ""
            padding: 32
            wrapMode: Text.WordWrap
            color: Theme.dim
            font.pixelSize: 14
        }
    }
}
