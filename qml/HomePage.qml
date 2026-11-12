import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "home"
    readonly property var home: library.home
    readonly property var sections: home.sections || []
    readonly property bool wide: width > 1000
    readonly property var liked: (library.likedRevision, library.likedPreview)
    // what the "now playing" card offers: the current track, else the last one played
    readonly property bool live: !!player.state.hasTrack
    readonly property var resume: live ? player.state : (library.recent.length > 0 ? library.recent[0] : null)

    Flickable {
        id: flick
        SmoothScroll { flickable: flick }
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 28
            y: 24
            width: flick.width - 56
            spacing: 28

            // ---- title + stats --------------------------------------------------------
            Column {
                width: parent.width
                spacing: 12
                RowLayout {
                    width: parent.width
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { Layout.fillWidth: true; text: "Beranda"; font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }
                        Label {
                            Layout.fillWidth: true
                            text: Theme.greeting() + (library.me.name ? ", " + library.me.name.split(" ")[0] : "")
                            color: Theme.dim
                            font.pixelSize: 14
                        }
                    }
                    NButton { text: "Muat ulang"; iconName: "refresh"; onClicked: library.refreshAll() }
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Chip { iconName: "heart"; text: library.likedCount + " lagu disukai"; onClicked: Nav.go("liked") }
                    Chip { iconName: "list"; text: library.ownPlaylists.length + " playlist"; onClicked: Nav.go("library") }
                    Chip {
                        iconName: "album"
                        text: (library.playlists.length - library.ownPlaylists.length) + " tersimpan"
                        onClicked: Nav.go("library")
                    }
                    Chip { iconName: "clock"; text: library.recent.length + " baru diputar"; enabled: false }
                }
            }

            // ---- now playing / resume card --------------------------------------------
            Rectangle {
                width: parent.width
                height: 104
                radius: 16
                color: Theme.surface
                border.color: Theme.line

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Cover {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        radius: 8
                        source: page.resume ? (page.resume.image || page.resume.imageSmall || "") : ""
                        fallbackIcon: "music"
                        HoverHandler { cursorShape: page.live ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler { onTapped: if (page.live) Nav.immersive(true) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: page.resume ? (page.live ? "Sedang diputar" : "Terakhir diputar") : "Selamat datang di Senada"
                            color: Theme.dim
                            font.pixelSize: 12
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.resume ? page.resume.name : "Musik tanpa akun, tanpa iklan"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.resume ? page.resume.artists + (page.resume.album ? " • " + page.resume.album : "")
                                              : "Cari lagu, buka album, atau impor playlist Spotify."
                            color: Theme.dim
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            visible: page.live
                            spacing: 10
                            Label {
                                text: Theme.fmt(player.position)
                                color: Theme.faint
                                font.pixelSize: 11
                                font.features: { "tnum": 1 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 2
                                radius: 1
                                color: Theme.surface3
                                Rectangle {
                                    height: parent.height
                                    radius: 1
                                    color: Theme.primary
                                    width: player.state.durationMs > 0
                                           ? parent.width * Math.min(1, player.position / player.state.durationMs) : 0
                                }
                            }
                            Label {
                                text: Theme.fmt(player.state.durationMs)
                                color: Theme.faint
                                font.pixelSize: 11
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                    IconButton {
                        visible: !!page.resume
                        iconName: page.live && player.state.isPlaying === true ? "pause" : "play"
                        size: 20
                        outlined: true
                        implicitWidth: 46
                        tip: page.live ? "Putar/Jeda" : "Lanjutkan"
                        onClicked: page.live ? player.togglePlay() : player.playUris(library.recent.map(t => t.uri), 0)
                    }
                    NButton {
                        visible: !page.resume
                        text: "Cari lagu"
                        iconName: "search"
                        primary: true
                        onClicked: Nav.go("search")
                    }
                }
            }

            // ---- quick actions --------------------------------------------------------
            Column {
                width: parent.width
                spacing: 12
                Label { text: "Aksi cepat"; font.pixelSize: 18; font.weight: Font.Bold }
                GridLayout {
                    width: parent.width
                    columns: page.wide ? 3 : 1
                    columnSpacing: 12
                    rowSpacing: 10
                    QuickAction {
                        iconName: "play"
                        title: "Lagu yang Disukai"
                        subtitle: library.likedCount + " lagu"
                        enabled: library.likedCount > 0
                        onClicked: player.playContext("senada:liked:", "")
                    }
                    QuickAction {
                        iconName: "shuffle"
                        title: "Acak"
                        subtitle: "Lagu yang disukai, urutan acak"
                        enabled: library.likedCount > 0
                        onClicked: player.shufflePlay("senada:liked:")
                    }
                    QuickAction {
                        iconName: "download"
                        title: "Impor dari Spotify"
                        subtitle: "Tempel link playlist atau album"
                        onClicked: Nav.go("library")
                    }
                }
            }

            // ---- liked + recently played, side by side ----------------------------------
            GridLayout {
                width: parent.width
                visible: page.liked.length > 0 || library.recent.length > 0
                columns: page.wide ? 2 : 1
                columnSpacing: 24
                rowSpacing: 24
                TrackColumn {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    title: "Disukai"
                    tracks: page.liked
                    emptyText: "Tekan ♡ di lagu mana pun untuk menyimpannya di sini."
                    onShowAll: Nav.go("liked")
                }
                TrackColumn {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    title: "Baru diputar"
                    tracks: library.recent.slice(0, 6)
                    allTracks: library.recent
                    emptyText: "Lagu yang kamu putar akan muncul di sini."
                }
            }

            // ---- YouTube Music shelves -----------------------------------------------------
            Column {
                width: parent.width
                visible: page.sections.length === 0
                spacing: 12
                RowLayout {
                    spacing: 12
                    BusyIndicator {
                        running: !!page.home.loading
                        visible: running
                        implicitWidth: 28; implicitHeight: 28
                    }
                    Label {
                        text: page.home.loading ? "Memuat musik dari YouTube Music…" : (page.home.error || "")
                        color: page.home.loading ? Theme.dim : Theme.danger
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                }
                NButton {
                    visible: !page.home.loading && !!page.home.error
                    text: "Coba lagi"
                    iconName: "refresh"
                    onClicked: library.refreshAll()
                }
            }

            Repeater {
                model: page.sections
                Column {
                    width: col.width
                    spacing: 12
                    TrackSection {
                        width: parent.width
                        title: modelData.title
                        tracks: modelData.tracks || []
                    }
                    Carousel {
                        width: parent.width
                        title: (modelData.tracks || []).length > 0 ? "" : modelData.title
                        items: modelData.cards || []
                    }
                }
            }
        }
    }

    // outlined action tile: icon in a ring, title and a hint
    component QuickAction: AbstractButton {
        id: qa
        property string iconName
        property string title
        property string subtitle
        Layout.fillWidth: true
        implicitHeight: 62
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        opacity: enabled ? 1 : 0.45
        background: Rectangle {
            radius: 14
            color: qa.hovered ? Theme.hover : "transparent"
            border.color: qa.hovered ? Theme.lineStrong : Theme.line
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: RowLayout {
            spacing: 14
            Rectangle {
                Layout.leftMargin: 12
                implicitWidth: 36; implicitHeight: 36; radius: 18
                color: Theme.hover
                Icon { anchors.centerIn: parent; glyph: qa.iconName; size: 18; color: Theme.text }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label { Layout.fillWidth: true; text: qa.title; font.pixelSize: 14; font.weight: Font.Bold; elide: Text.ElideRight }
                Label { Layout.fillWidth: true; text: qa.subtitle; color: Theme.dim; font.pixelSize: 12; elide: Text.ElideRight }
            }
        }
    }

    // a titled, numbered list of a few tracks with an "All →" link
    component TrackColumn: Column {
        id: tcol
        property string title
        property var tracks: []
        property var allTracks: tracks
        property string emptyText
        signal showAll()
        spacing: 6
        Item {
            width: parent.width
            height: 32
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: tcol.title
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            LinkLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: tcol.title === "Disukai" && tcol.tracks.length > 0
                text: "Semua →"
                font.weight: Font.Bold
                onClicked: tcol.showAll()
            }
        }
        Label {
            visible: tcol.tracks.length === 0
            width: parent.width
            text: tcol.emptyText
            color: Theme.faint
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Repeater {
            model: tcol.tracks
            TrackRow {
                width: tcol.width
                track: modelData
                number: index + 1
                showAlbum: false
                onPlay: player.playUris(tcol.allTracks.map(x => x.uri), index)
            }
        }
    }

    // titled tracks in one or two columns; shows a few rows and expands on demand
    component TrackSection: Column {
        id: ts
        property string title
        property var tracks: []
        property bool expanded: false
        readonly property int cols: page.wide ? 2 : 1
        readonly property int collapsed: cols * 3
        visible: tracks.length > 0
        spacing: 6

        Item {
            width: parent.width
            height: 40
            Label {
                text: ts.title
                font.pixelSize: 18
                font.weight: Font.Bold
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Chip {
                    text: "Putar semua"
                    iconName: "play"
                    onClicked: player.playUris(ts.tracks.map(x => x.uri), 0)
                }
                Chip {
                    visible: ts.tracks.length > ts.collapsed
                    text: ts.expanded ? "Lebih sedikit" : "Semua (" + ts.tracks.length + ")"
                    onClicked: ts.expanded = !ts.expanded
                }
            }
        }
        GridLayout {
            width: parent.width
            columns: ts.cols
            columnSpacing: 24
            rowSpacing: 0
            Repeater {
                model: ts.expanded ? ts.tracks : ts.tracks.slice(0, ts.collapsed)
                TrackRow {
                    Layout.fillWidth: true
                    Layout.preferredWidth: ts.width / ts.cols
                    track: modelData
                    number: index + 1
                    showAlbum: ts.cols === 1
                    onPlay: player.playUris(ts.tracks.map(x => x.uri), index)
                }
            }
        }
    }
}
