import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "home"
    readonly property var home: library.home
    readonly property var sections: home.sections || []
    readonly property bool wide: width > 1100
    // what "Lanjut dengar" offers: the current track, else the last one played
    readonly property var resume: player.state.hasTrack ? player.state : (library.recent.length > 0 ? library.recent[0] : null)

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 24
            y: 4
            width: flick.width - 48
            spacing: 34

            // greeting
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    spacing: 2
                    Label {
                        text: Theme.greeting().toUpperCase()
                        color: Theme.mint
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }
                    Label {
                        width: parent.width
                        text: (library.me.name ? library.me.name.split(" ")[0] : "Hai") + ","
                        font.pixelSize: 44
                        font.weight: Font.Black
                        font.letterSpacing: -1.2
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "mau dengar apa hari ini?"
                        color: Theme.dim
                        font.pixelSize: 20
                    }
                }
                IconButton { iconName: "refresh"; tint: Theme.dim; tip: "Muat ulang"; onClicked: library.refreshAll() }
            }

            // resume card + library tiles
            GridLayout {
                width: parent.width
                columns: page.wide ? 2 : 1
                columnSpacing: 20
                rowSpacing: 20

                // "Lanjut dengar"
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: page.wide ? parent.width * 0.48 : parent.width
                    implicitHeight: 176
                    radius: 36
                    color: Theme.glass
                    border.color: Theme.glassBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 22
                        Cover {
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 132
                            scalloped: true
                            scallops: 16
                            scallopDepth: 0.045
                            source: page.resume ? (page.resume.image || page.resume.imageSmall || "") : ""
                            fallbackIcon: "note"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                text: page.resume ? (player.state.hasTrack ? "SEDANG DIPUTAR" : "LANJUT DENGAR") : "SELAMAT DATANG"
                                color: Theme.mint
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.letterSpacing: 1.6
                            }
                            Label {
                                Layout.fillWidth: true
                                text: page.resume ? page.resume.name : "Musik tanpa akun, tanpa iklan"
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: page.resume ? page.resume.artists : "Pilih lagu di bawah atau cari apa saja."
                                color: Theme.dim
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                            Row {
                                Layout.topMargin: 10
                                spacing: 10
                                visible: !!page.resume
                                BloomPlayButton {
                                    size: 46
                                    playing: player.state.hasTrack && player.state.isPlaying === true
                                    onClicked: player.state.hasTrack ? player.togglePlay()
                                                                     : player.playUris(library.recent.map(t => t.uri), 0)
                                }
                                NButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Radio"
                                    iconName: "equalizer"
                                    onClicked: player.playRadio(page.resume.uri)
                                }
                            }
                        }
                    }
                }

                // library tiles
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: [{ kind: "liked", id: "", name: "Lagu yang Disukai", imageSmall: "" }].concat(library.playlists.slice(0, 5))
                        AbstractButton {
                            id: tile
                            width: page.wide ? (parent.width - 10) / 2 : Math.max(220, (parent.width - 20) / 3)
                            implicitHeight: 52
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: Nav.go(modelData.kind, modelData.id)
                            background: Rectangle {
                                radius: 26
                                color: tile.hovered ? Theme.glassHover : Theme.glass
                                border.color: Theme.glassBorder
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Item {
                                    Layout.leftMargin: 6
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    Scallop {
                                        anchors.fill: parent
                                        visible: modelData.kind === "liked"
                                        lobes: 10; depth: 0.08
                                        color: Theme.fuchsia
                                    }
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: modelData.kind === "liked"
                                        glyph: "heart"; size: 18; color: "#2a0614"
                                    }
                                    Cover {
                                        anchors.fill: parent
                                        visible: modelData.kind !== "liked"
                                        radius: 20
                                        scalloped: modelData.kind === "artist"
                                        source: modelData.imageSmall || ""
                                        fallbackIcon: modelData.kind === "artist" ? "speaker" : "note"
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.rightMargin: 14
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                    Chip {
                        text: "Semua di Library"
                        iconName: "library"
                        height: 52
                        onClicked: Nav.go("library")
                    }
                }
            }

            TrackSection {
                width: parent.width
                title: "Baru saja diputar"
                tracks: library.recent
            }

            // loading / error state for the YouTube Music shelves
            Column {
                width: parent.width
                visible: page.sections.length === 0
                spacing: 12
                RowLayout {
                    x: 12
                    spacing: 12
                    BusyIndicator {
                        running: !!page.home.loading
                        visible: running
                        implicitWidth: 32; implicitHeight: 32
                    }
                    Label {
                        text: page.home.loading ? "Memuat musik dari YouTube Music…" : (page.home.error || "")
                        color: page.home.loading ? Theme.dim : Theme.danger
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                }
                NButton {
                    x: 12
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
            height: 44
            Label {
                text: ts.title
                font.pixelSize: 22
                font.weight: Font.Bold
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
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
            columnSpacing: 0
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
