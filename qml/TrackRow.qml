import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One song. Three layouts:
//   table    columns # | title | artist | album | length, separated by lines (album/playlist pages);
//            column widths match TrackTableHeader through the same stretch factors
//   default  cover with title and artist stacked (home, search)
//   compact  cover, title/artist and length only (the right-hand queue panel)
Item {
    id: row
    property var track: ({})
    property int number: 0
    property bool showCover: true
    property bool showAlbum: true
    property bool table: false
    property bool compact: false
    property real inset: 0          // side gutter inside full-width table rows
    property bool removable: false  // shows "Hapus dari playlist ini" (own playlists)
    readonly property bool isYouTube: (track.uri || "").indexOf("yt:track:") === 0
    readonly property bool current: track.uri !== undefined && player.state.uri === track.uri
    readonly property bool playing: current && player.state.isPlaying
    readonly property bool liked: (library.likedRevision, library.isLiked(track.uri || ""))
    // 101 downloaded, 0-100 downloading, -1 waiting, -2 not downloaded
    readonly property int dl: (downloads.revision, downloads.progressRevision, downloads.stateOf(track.uri || ""))
    readonly property bool downloadable: isYouTube || (track.uri || "").indexOf("spotify:track:") === 0
    readonly property bool imported: (track.uri || "").indexOf("spotify:track:") === 0
    readonly property bool unsure: imported && track.matchScore !== undefined && track.matchScore < library.matchThreshold
    readonly property bool wideTable: table && width - 2 * inset > 560
    readonly property bool albumColumn: width - 2 * inset > 760
    // colours follow the inherited palette, so rows also read well in the (always dark) immersive queue
    readonly property color ink: palette.windowText
    readonly property color dimInk: Theme.alpha(ink, 0.62)
    readonly property color hiInk: Theme.accented ? Theme.accentInkOn(Theme.luma(ink) > 0.5) : ink  // the playing song
    signal play()
    signal remove()

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 400)
    height: table ? (showCover ? 56 : 48) : compact ? 54 : 60
    opacity: track.playable === false ? 0.45 : 1

    HoverHandler { id: hover }
    TapHandler { onDoubleTapped: row.play() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: menu.popup() }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.table ? row.inset : 6
        anchors.rightMargin: row.table ? row.inset : 6
        anchors.topMargin: row.table ? 0 : 1
        anchors.bottomMargin: row.table ? 0 : 1
        radius: row.table ? 0 : 8
        color: row.current ? (Theme.accented ? Theme.alpha(Theme.primary, 0.15) : Theme.alpha(row.ink, 0.08))
             : hover.hovered ? Theme.alpha(row.ink, 0.045) : "transparent"
    }
    Rectangle {  // table row separator
        visible: row.table
        anchors.bottom: parent.bottom
        x: row.inset
        width: parent.width - 2 * row.inset
        height: 1
        color: Theme.alpha(row.ink, 0.08)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.table ? row.inset + 12 : 14
        anchors.rightMargin: row.table ? row.inset + 8 : 10
        spacing: 12

        // # column: number, a live equalizer on the playing row, or play on hover
        Item {
            visible: row.table || (!row.compact && row.number > 0)
            Layout.preferredWidth: 26
            Layout.fillHeight: true
            Label {
                anchors.centerIn: parent
                visible: !hover.hovered && !row.current
                text: row.number > 0 ? row.number : ""
                color: row.dimInk
                font.pixelSize: 13
                font.features: { "tnum": 1 }
            }
            Row {  // live equalizer
                anchors.centerIn: parent
                visible: row.current && !hover.hovered
                spacing: 2
                height: 14
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 3
                        radius: 1.5
                        color: row.hiInk
                        anchors.bottom: parent.bottom
                        height: 5
                        // only while Senada is the focused window: an endless animation makes
                        // Qt redraw the window all the time, also when nobody sees it
                        SequentialAnimation on height {
                            running: row.playing && row.Window.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 14 - index * 3; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4 + index * 2; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: hover.hovered
                glyph: row.playing ? "pause" : "play"
                size: 18
                color: row.ink
            }
            MouseArea {
                anchors.fill: parent
                visible: hover.hovered
                cursorShape: Qt.PointingHandCursor
                onClicked: row.playing ? player.togglePlay() : row.play()
            }
        }

        Item {
            visible: row.showCover
            Layout.preferredWidth: row.table ? 38 : 42
            Layout.preferredHeight: row.table ? 38 : 42
            Cover {
                anchors.fill: parent
                radius: 5
                source: row.track.imageSmall || ""
                simple: true
            }
            // compact/default rows without a # column play from the cover
            Rectangle {
                anchors.fill: parent
                radius: 5
                visible: (row.compact || row.number <= 0) && !row.table && (hover.hovered || row.current)
                color: Qt.rgba(0, 0, 0, 0.5)
                Icon {
                    anchors.centerIn: parent
                    glyph: row.playing || (row.current && !hover.hovered) ? (hover.hovered ? "pause" : "equalizer") : "play"
                    size: 18
                    color: row.current && !hover.hovered && Theme.accented ? Theme.accentInkOn(true) : "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.playing ? player.togglePlay() : row.play()
                }
            }
        }

        // title (+ artist under it unless this is a wide table)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 4
            Layout.minimumWidth: 100
            spacing: 1
            // title with its badges right after it; positioned by hand (no layout) so the
            // title can elide without feeding its width back into the row's layout
            Item {
                id: titleRow
                Layout.fillWidth: true
                implicitHeight: titleLabel.implicitHeight
                Label {
                    id: titleLabel
                    width: Math.max(0, Math.min(implicitWidth, titleRow.width - badgeRow.width - (badgeRow.width > 0 ? 6 : 0)))
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.track.name || ""
                    elide: Text.ElideRight
                    font.pixelSize: row.compact ? 13 : 14
                    font.weight: row.current ? Font.Bold : Font.Normal
                    color: row.current ? row.hiInk : row.ink
                }
                Row {
                    id: badgeRow
                    x: titleLabel.width + 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon {  // liked
                        visible: row.liked && row.table
                        glyph: "heart"
                        size: 14
                        color: Theme.like
                    }
                    Badge { visible: !!row.track.explicit; text: "E" }
                    DownloadButton {  // kept for offline, or on its way
                        visible: row.dl !== -2
                        track: row.track
                        size: 14
                        tint: row.dimInk
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    Rectangle {  // the YouTube Music match for this imported song may be off
                        visible: row.unsure
                        width: 16; height: 16; radius: 8
                        color: Theme.alpha(Theme.warn, 0.2)
                        border.color: Theme.warn
                        Label { anchors.centerIn: parent; text: "?"; font.pixelSize: 10; font.bold: true; color: Theme.warn }
                        HoverHandler { id: unsureHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Nav.matchPicker(row.track) }
                        ToolTip.visible: unsureHover.hovered
                        ToolTip.text: I18n.t("The YouTube Music version may not be the right one — click to pick another")
                        ToolTip.delay: 300
                    }
                }
            }
            LinkLabel {
                visible: !row.wideTable
                Layout.fillWidth: true
                text: row.track.artists || ""
                font.pixelSize: 12
                onClicked: if (row.track.artistId) Nav.go("artist", row.track.artistId)
            }
        }

        // table columns
        Item {
            visible: row.wideTable
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 3
            Layout.fillHeight: true
            LinkLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: row.track.artists || ""
                onClicked: if (row.track.artistId) Nav.go("artist", row.track.artistId)
            }
        }
        Item {
            visible: row.showAlbum && row.albumColumn && (row.wideTable || (!row.table && !row.compact))
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 3
            Layout.fillHeight: true
            LinkLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: row.track.album || ""
                onClicked: if (row.track.albumId) Nav.go("album", row.track.albumId)
            }
        }

        Label {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: row.track.durationMs ? Theme.fmt(row.track.durationMs) : ""
            color: row.dimInk
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
        // actions
        Row {
            Layout.preferredWidth: row.compact ? 30 : row.table ? 64 : 94
            layoutDirection: Qt.RightToLeft
            spacing: 0
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "more"
                size: 16
                tint: row.dimInk
                tip: I18n.t("Song options")
                opacity: hover.hovered || menu.opened || !row.compact ? 1 : 0
                onClicked: menu.popup()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.compact
                iconName: row.liked ? "heart" : "heart-outline"
                size: 16
                tint: row.liked ? Theme.like : row.dimInk
                tip: row.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                opacity: hover.hovered || (row.liked && !row.table) ? 1 : 0
                onClicked: player.setLiked(row.track.uri, !row.liked)
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.compact && !row.table
                iconName: "queue-add"
                size: 16
                tint: row.dimInk
                tip: I18n.t("Add to queue")
                opacity: hover.hovered ? 1 : 0
                onClicked: player.addToQueue(row.track.uri)
            }
        }
    }

    component Badge: Rectangle {
        property alias text: badgeLabel.text
        width: 16; height: 16; radius: 4
        color: Theme.alpha(row.ink, 0.22)
        Label { id: badgeLabel; anchors.centerIn: parent; font.pixelSize: 10; font.bold: true; color: row.ink }
    }

    NMenu {
        id: menu
        MenuItem { text: I18n.t("Play"); onTriggered: row.play() }
        MenuItem { text: I18n.t("Play radio from this song"); onTriggered: player.playRadio(row.track.uri) }
        MenuItem { text: I18n.t("Add to queue"); onTriggered: player.addToQueue(row.track.uri) }
        MenuItem {
            text: row.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
            onTriggered: player.setLiked(row.track.uri, !row.liked)
        }
        NMenu {
            id: addMenu
            title: I18n.t("Add to playlist")
            MenuItem { text: I18n.t("+ New playlist…"); onTriggered: Nav.newPlaylist([row.track]) }
            MenuSeparator {}
            Instantiator {
                model: library.ownPlaylists
                delegate: MenuItem {
                    text: modelData.name
                    onTriggered: library.addToPlaylist(modelData.id, [row.track])
                }
                onObjectAdded: (index, object) => addMenu.insertItem(index + 2, object)
                onObjectRemoved: (index, object) => addMenu.removeItem(object)
            }
        }
        MenuItem {
            visible: row.downloadable
            height: visible ? implicitHeight : 0
            text: row.dl === 101 ? I18n.t("Remove download")
                : row.dl === -2 ? I18n.t("Download for offline")
                : I18n.t("Cancel download")
            onTriggered: row.dl === -2 ? downloads.download([row.track]) : downloads.remove(row.track.uri)
        }
        MenuItem {
            visible: row.imported
            height: visible ? implicitHeight : 0
            text: I18n.t("Pick another version…")
            onTriggered: Nav.matchPicker(row.track)
        }
        MenuItem {
            visible: row.removable
            height: visible ? implicitHeight : 0
            text: I18n.t("Remove from this playlist")
            onTriggered: row.remove()
        }
        MenuItem { text: I18n.t("Go to album"); enabled: !!row.track.albumId; onTriggered: Nav.go("album", row.track.albumId) }
        MenuItem { text: I18n.t("Go to artist"); enabled: !!row.track.artistId; onTriggered: Nav.go("artist", row.track.artistId) }
        MenuItem {
            text: I18n.t("Copy song link")
            onTriggered: session.copy(row.isYouTube ? "https://music.youtube.com/watch?v=" + row.track.id
                                                    : "https://open.spotify.com/track/" + row.track.id)
        }
    }
}
