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
        "Top hits Indonesia", I18n.t("Chill lo-fi"), "Dangdut koplo", I18n.t("Late night jazz"),
        "K-Pop", I18n.t("Sad songs"), I18n.t("Indonesian indie"), I18n.t("Focus music")
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
        SmoothScroll { flickable: flick }
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 28
            y: 24
            width: flick.width - 56
            spacing: 22

            Label { text: I18n.t("Search"); font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }

            // search field
            Item {
                width: parent.width
                height: 50
                NTextField {
                    id: field
                    width: Math.min(720, parent.width)
                    height: 50
                    font.pixelSize: 15
                    iconName: "search"
                    placeholderText: I18n.t("What do you want to hear? (or paste a Spotify/YouTube Music link)")
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
                spacing: 8
                visible: page.hasResults
                Repeater {
                    model: [
                        { key: "all", label: I18n.t("All") },
                        { key: "tracks", label: I18n.t("Songs") },
                        { key: "albums", label: I18n.t("Albums") },
                        { key: "artists", label: I18n.t("Artists") },
                        { key: "playlists", label: I18n.t("Playlists") }
                    ]
                    Chip {
                        text: modelData.label
                        checked: page.filter === modelData.key
                        onClicked: page.filter = modelData.key
                    }
                }
            }

            // empty state: suggestions
            Column {
                width: parent.width
                visible: !page.hasResults && !page.searching
                spacing: 14
                Label {
                    text: field.text.trim() ? I18n.t("No results.") : I18n.t("Try one of these, or paste a Spotify or YouTube Music playlist link.")
                    color: Theme.dim
                    font.pixelSize: 15
                }
                Flow {
                    width: parent.width
                    spacing: 10
                    visible: !field.text.trim()
                    Repeater {
                        model: page.suggestions
                        AbstractButton {
                            id: sug
                            width: 200; height: 64
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: field.text = modelData
                            background: Rectangle {
                                radius: 14
                                color: sug.hovered ? Theme.hover : "transparent"
                                border.color: sug.hovered ? Theme.lineStrong : Theme.line
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Rectangle {
                                    Layout.leftMargin: 12
                                    implicitWidth: 36; implicitHeight: 36; radius: 18
                                    color: Theme.hover
                                    Icon { anchors.centerIn: parent; glyph: "search"; size: 16; color: Theme.text }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.rightMargin: 12
                                    text: modelData
                                    elide: Text.ElideRight
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
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
                    implicitHeight: 250
                    radius: 16
                    color: Theme.surface
                    border.color: Theme.line
                    readonly property var hit: page.tracks[0] || ({})
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 6
                        Label { text: I18n.t("Top result"); color: Theme.dim; font.pixelSize: 12; font.weight: Font.Bold }
                        Cover {
                            Layout.topMargin: 8
                            Layout.preferredWidth: 104; Layout.preferredHeight: 104
                            radius: 10
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
                            IconButton {
                                iconName: "play"
                                size: 24
                                filled: true
                                tip: I18n.t("Play")
                                onClicked: player.playUris(page.tracks.map(x => x.uri), 0)
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: I18n.t("Songs"); font.pixelSize: 18; font.weight: Font.Bold; bottomPadding: 6 }
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
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: I18n.t("Artists"); items: page.results.artists || [] }
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: I18n.t("Albums"); items: page.results.albums || [] }
            Carousel { width: parent.width; visible: page.filter === "all" && items.length > 0; title: I18n.t("Playlists"); items: page.results.playlists || [] }
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
