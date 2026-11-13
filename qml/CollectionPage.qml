import QtQuick
import QtQuick.Controls

// Playlist, album, liked songs and offline (downloaded) songs.
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
    readonly property var tracks: info.tracks || []
    // table sorting: "" keeps the collection's own order
    property string sortKey: ""
    property bool sortAsc: true
    readonly property var shown: {
        const t = tracks.map((x, i) => Object.assign({}, x, { number: i + 1 }))
        if (!sortKey) return t
        const k = sortKey, dir = sortAsc ? 1 : -1
        return t.sort((a, b) => {
            const x = a[k], y = b[k]
            if (typeof x === "number" || typeof y === "number") return ((x || 0) - (y || 0)) * dir
            return String(x || "").localeCompare(String(y || ""), undefined, { sensitivity: "base" }) * dir
        })
    }
    function sortBy(key) {
        if (key === "number" || (sortKey === key && !sortAsc)) { sortKey = ""; sortAsc = true }
        else if (sortKey === key) sortAsc = false
        else { sortKey = key; sortAsc = true }
    }
    readonly property bool isSpotify: itemId.indexOf("sp-") === 0
    readonly property bool isOffline: kind === "offline"
    // how many of these songs are downloaded, for the "download all" button
    readonly property int downloadedCount: (downloads.revision, downloads.downloadedCount(tracks.map(t => t.uri)))

    Connections {
        target: downloads
        function onChanged() { if (page.isOffline) library.load(page.kind, page.itemId) }
    }

    Connections {
        target: library
        function onLoaded(key, data) {
            if (key !== page.pageKey) return
            page.info = data
            page.loading = false
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
        if (sortKey) {  // sorted view: play in the order shown
            player.playUris(shown.map(x => x.uri), i)
            return
        }
        const t = tracks
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
        SmoothScroll { flickable: list }
        anchors.fill: parent
        clip: true
        currentIndex: -1  // don't auto-scroll to the first row (it would clip the header)
        // when the header grows (cover, title, "Lagu teratas" arrive later) and the user hasn't
        // scrolled yet, stay at the very top instead of letting the header slide up under the bar
        property real lastOriginY: 0
        onOriginYChanged: {
            if (!moving && contentY <= lastOriginY + 1)
                contentY = originY
            lastOriginY = originY
        }
        model: page.shown
        reuseItems: true
        bottomMargin: Theme.dockSpace
        ScrollBar.vertical: NScrollBar {}

        header: Column {
          width: list.width
          PageHeader {
            width: list.width
            info: page.info
            loading: page.loading
            fallbackIcon: page.kind === "liked" ? "heart" : page.isOffline ? "downloaded" : "note"
            canSave: page.kind !== "liked" && !page.isOffline && !page.isLocal && !page.isSpotify && !page.info.error
            canDownload: !page.isOffline && !page.info.error && page.tracks.length > 0
            downloadedCount: page.downloadedCount
            trackCount: page.tracks.length
            saved: (library.savedRevision, library.isSaved(page.kind, page.itemId))
            canImport: page.isSpotify && (page.info.tracks || []).length > 0
            isLocal: page.isLocal
            onPlayAll: page.playAll()
            onShuffleAll: page.shuffleAll()
            onSaveToggled: library.toggleSaved(page.info)
            onImportRequested: library.importCollection(page.info)
            onDownloadAll: downloads.download(page.tracks)
            onRenameRequested: Nav.renamePlaylist(page.itemId, page.info.name)
            onDeleteRequested: Nav.deletePlaylist(page.itemId, page.info.name)
          }
          // offline songs: what is downloading right now
          Item {
            id: downloadStrip
            visible: page.isOffline && downloads.pending > 0
            width: list.width
            height: visible ? 44 : 0
            Row {
              x: 32
              anchors.verticalCenter: parent.verticalCenter
              spacing: 12
              BusyIndicator {
                anchors.verticalCenter: parent.verticalCenter
                running: downloadStrip.visible
                implicitWidth: 22
                implicitHeight: 22
              }
              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: downloads.current.name
                      ? I18n.t("Downloading “{name}” — {p}%", { name: downloads.current.name, p: downloads.current.progress })
                        + (downloads.pending > 1 ? "  ·  " + I18n.n("{n} more waiting", "{n} more waiting", downloads.pending - 1) : "")
                      : I18n.t("Getting ready to download…")
                color: Theme.dim
                font.pixelSize: 13
              }
              LinkLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Cancel all")
                font.pixelSize: 13
                onClicked: downloads.cancelAll()
              }
            }
          }
          TrackTableHeader {
            visible: page.tracks.length > 0
            width: list.width
            inset: 16
            showCover: page.kind !== "album"
            showAlbum: page.kind !== "album"
            sortKey: page.sortKey
            sortAsc: page.sortAsc
            onSortBy: (key) => page.sortBy(key)
          }
        }

        delegate: TrackRow {
            inset: 16
            table: true
            track: modelData
            number: modelData.number
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
