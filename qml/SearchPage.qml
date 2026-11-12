import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "search"
    property var results: ({})
    property bool searching: false
    property string lastQuery: ""
    property string filter: "all"  // all | tracks | albums | artists | playlists
    readonly property var tracks: results.tracks || []
    readonly property bool hasResults: tracks.length + (results.albums || []).length
                                       + (results.artists || []).length + (results.playlists || []).length > 0
    readonly property var suggestions: [
        { text: "Top hits Indonesia", color: Theme.mint },
        { text: "Lo-fi santai", color: "#8fb8ff" },
        { text: "Dangdut koplo", color: Theme.fuchsia },
        { text: "Jazz malam", color: "#ffc36b" },
        { text: "K-Pop", color: "#c79bff" },
        { text: "Lagu galau", color: "#7fd9ff" },
        { text: "Indie Indonesia", color: "#9bf08a" },
        { text: "Musik fokus", color: "#ff9a7a" }
    ]

    Component.onCompleted: field.forceActiveFocus()

    Connections {
        target: library
        function onSearchFinished(query, data) {
            if (query !== page.lastQuery) return
            page.searching = false
            page.results = data
            if (data.error) session.toast(data.error)
        }
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: {
            const q = field.text.trim()
            if (!q) { page.results = {}; return }
            page.lastQuery = q
            page.searching = true
            library.search(q)
        }
    }

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
            spacing: 26

            // big search capsule
            Item {
                width: parent.width
                height: 64
                NTextField {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(720, parent.width)
                    height: 60
                    font.pixelSize: 18
                    iconName: "search"
                    placeholderText: "Mau dengar apa? (atau tempel link Spotify/YouTube Music)"
                    onTextChanged: debounce.restart()
                    Keys.onEscapePressed: text = ""
                }
                BusyIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: field.right
                    anchors.rightMargin: 10
                    running: page.searching
                    visible: running
                    implicitWidth: 32; implicitHeight: 32
                }
            }

            // filters
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                visible: page.hasResults
                Repeater {
                    model: [
                        { key: "all", label: "Semua" },
                        { key: "tracks", label: "Lagu" },
                        { key: "albums", label: "Album" },
                        { key: "artists", label: "Artis" },
                        { key: "playlists", label: "Playlist" }
                    ]
                    Chip {
                        text: modelData.label
                        checked: page.filter === modelData.key
                        onClicked: page.filter = modelData.key
                    }
                }
            }

            // empty state: suggestion blooms
            Column {
                width: parent.width
                visible: !page.hasResults && !page.searching
                spacing: 18
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: field.text.trim() ? "Tidak ada hasil." : "Coba salah satu, atau tempel link playlist Spotify publik."
                    color: Theme.dim
                    font.pixelSize: 15
                }
                Flow {
                    width: Math.min(820, parent.width)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    visible: !field.text.trim()
                    Repeater {
                        model: page.suggestions
                        AbstractButton {
                            id: sug
                            width: 186; height: 112
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: field.text = modelData.text
                            background: Rectangle {
                                radius: 28
                                color: sug.hovered ? Theme.glassHover : Theme.glass
                                border.color: Theme.glassBorder
                                clip: true
                                Scallop {
                                    width: 96; height: 96
                                    x: parent.width - 62; y: parent.height - 64
                                    lobes: 8 + index; depth: 0.14
                                    color: modelData.color
                                    opacity: sug.hovered ? 0.9 : 0.62
                                    rotation: sug.hovered ? 30 : 0
                                    Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                }
                            }
                            contentItem: Label {
                                text: modelData.text
                                wrapMode: Text.WordWrap
                                leftPadding: 18; topPadding: 16; rightPadding: 40
                                verticalAlignment: Text.AlignTop
                                font.pixelSize: 17
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }

            // "Semua": top result next to the first songs
            GridLayout {
                width: parent.width
                visible: page.filter === "all" && page.tracks.length > 0
                columns: width > 980 ? 2 : 1
                columnSpacing: 20
                rowSpacing: 12

                Rectangle {
                    id: topCard
                    Layout.preferredWidth: parent.columns === 2 ? parent.width * 0.38 : parent.width
                    Layout.fillHeight: parent.columns === 2
                    implicitHeight: 260
                    radius: 36
                    color: Theme.glass
                    border.color: Theme.glassBorder
                    readonly property var hit: page.tracks[0] || ({})
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 6
                        Label { text: "HASIL TERATAS"; color: Theme.mint; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.6 }
                        Cover {
                            Layout.topMargin: 8
                            Layout.preferredWidth: 104; Layout.preferredHeight: 104
                            scalloped: true; scallops: 14; scallopDepth: 0.05
                            source: topCard.hit.image || topCard.hit.imageSmall || ""
                        }
                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            text: topCard.hit.name || ""
                            font.pixelSize: 26; font.weight: Font.Black
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            LinkLabel {
                                Layout.fillWidth: true
                                text: (topCard.hit.artists || "") + (topCard.hit.album ? " • " + topCard.hit.album : "")
                                font.pixelSize: 14
                                onClicked: if (topCard.hit.artistId) Nav.go("artist", topCard.hit.artistId)
                            }
                            BloomPlayButton {
                                size: 52
                                tip: "Putar"
                                onClicked: player.playUris(page.tracks.map(x => x.uri), 0)
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Lagu"; font.pixelSize: 22; font.weight: Font.Bold; leftPadding: 12; bottomPadding: 6 }
                    Repeater {
                        model: page.tracks.slice(0, 5)
                        TrackRow {
                            width: parent.width
                            track: modelData
                            number: index + 1
                            showAlbum: false
                            onPlay: player.playUris(page.tracks.map(x => x.uri), index)
                        }
                    }
                }
            }

            // "Lagu": the full list
            Column {
                width: parent.width
                visible: page.filter === "tracks" && page.tracks.length > 0
                Repeater {
                    model: page.filter === "tracks" ? page.tracks : []
                    TrackRow {
                        width: col.width
                        track: modelData
                        number: index + 1
                        onPlay: player.playUris(page.tracks.map(x => x.uri), index)
                    }
                }
            }

            // shelves (Semua) or grids (single filter)
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: "Artis"; items: page.results.artists || [] }
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: "Album"; items: page.results.albums || [] }
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: "Playlist"; items: page.results.playlists || [] }
            CardGrid {
                width: parent.width
                visible: page.filter !== "all" && page.filter !== "tracks" && items.length > 0
                items: page.filter === "albums" ? (page.results.albums || [])
                     : page.filter === "artists" ? (page.results.artists || [])
                     : page.filter === "playlists" ? (page.results.playlists || []) : []
                rows: 99
                expanded: true
            }
        }
    }
}
