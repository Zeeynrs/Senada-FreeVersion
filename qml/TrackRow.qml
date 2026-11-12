import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One song as a glass pill: cover (or number) with a play overlay, a live mint
// equalizer on the playing row, inline like and queue actions.
Item {
    id: row
    property var track: ({})
    property int number: 0
    property bool showCover: true
    property bool showAlbum: true
    property bool removable: false  // shows "Hapus dari playlist ini" (own playlists)
    readonly property bool isYouTube: (track.uri || "").indexOf("yt:track:") === 0
    readonly property bool current: track.uri !== undefined && player.state.uri === track.uri
    readonly property bool playing: current && player.state.isPlaying
    readonly property bool liked: (library.likedRevision, library.isLiked(track.uri || ""))
    readonly property bool imported: (track.uri || "").indexOf("spotify:track:") === 0
    readonly property bool unsure: imported && track.matchScore !== undefined && track.matchScore < library.matchThreshold
    signal play()
    signal remove()

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 400)
    height: 62
    opacity: track.playable === false ? 0.45 : 1

    HoverHandler { id: hover }
    TapHandler { onDoubleTapped: row.play() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: menu.popup() }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 18
        color: row.current ? Theme.alpha(Theme.mint, hover.hovered ? 0.13 : 0.09)
                           : hover.hovered ? Theme.glass : "transparent"
        border.width: row.current ? 1 : 0
        border.color: Theme.alpha(Theme.mint, 0.22)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        // leading: cover (or track number) with play overlay / live equalizer
        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44

            Cover {
                visible: row.showCover
                anchors.fill: parent
                radius: 12
                source: row.track.imageSmall || ""
                simple: true
            }
            Rectangle {
                visible: !row.showCover
                anchors.fill: parent
                radius: 14
                color: Theme.glass
                Label {
                    anchors.centerIn: parent
                    text: row.number > 0 ? row.number : ""
                    color: row.current ? Theme.mint : Theme.dim
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
            // veil + icon on hover or while this row plays
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Theme.alpha(Theme.bg, 0.55)
                visible: hover.hovered || row.current
            }
            Icon {
                anchors.centerIn: parent
                visible: hover.hovered
                glyph: row.playing ? "pause" : "play"
                size: 20
                color: Theme.mint
            }
            Row {  // live equalizer
                anchors.centerIn: parent
                visible: row.current && !hover.hovered
                spacing: 3
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 4
                        radius: 2
                        color: Theme.mint
                        anchors.bottom: parent.bottom
                        height: 6
                        SequentialAnimation on height {
                            running: row.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: 18 - index * 3; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 5 + index * 2; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                visible: hover.hovered
                cursorShape: Qt.PointingHandCursor
                onClicked: row.playing ? player.togglePlay() : row.play()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: row.track.name || ""
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.Medium
                color: row.current ? Theme.mint : Theme.text
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {  // the YouTube Music match for this imported song may be off
                    visible: row.unsure
                    implicitWidth: 16; implicitHeight: 16; radius: 8
                    color: Theme.alpha(Theme.fuchsia, 0.25)
                    border.color: Theme.fuchsia
                    Label { anchors.centerIn: parent; text: "?"; font.pixelSize: 10; font.bold: true; color: Theme.fuchsia }
                    HoverHandler { id: unsureHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Nav.matchPicker(row.track) }
                    ToolTip.visible: unsureHover.hovered
                    ToolTip.text: "Versi YouTube Music-nya mungkin kurang tepat — klik untuk memilih versi lain"
                    ToolTip.delay: 300
                }
                Rectangle {
                    visible: !!row.track.explicit
                    implicitWidth: 16; implicitHeight: 16; radius: 5
                    color: Theme.alpha(Theme.text, 0.22)
                    Label { anchors.centerIn: parent; text: "E"; font.pixelSize: 10; font.bold: true; color: Theme.bg }
                }
                LinkLabel {
                    Layout.fillWidth: true
                    text: row.track.artists || ""
                    onClicked: if (row.track.artistId) Nav.go("artist", row.track.artistId)
                }
            }
        }

        LinkLabel {
            visible: row.showAlbum && row.width > 760
            Layout.preferredWidth: row.width * 0.26
            text: row.track.album || ""
            onClicked: if (row.track.albumId) Nav.go("album", row.track.albumId)
        }

        IconButton {
            iconName: row.liked ? "heart" : "heart-outline"
            size: 17
            tint: row.liked ? Theme.fuchsia : Theme.dim
            tip: row.liked ? "Hapus dari Lagu Disukai" : "Simpan ke Lagu Disukai"
            opacity: hover.hovered || row.liked ? 1 : 0
            onClicked: player.setLiked(row.track.uri, !row.liked)
        }
        IconButton {
            iconName: "queue-add"
            size: 17
            tint: Theme.dim
            tip: "Tambah ke antrean"
            opacity: hover.hovered ? 1 : 0
            onClicked: player.addToQueue(row.track.uri)
        }

        Label {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: row.track.durationMs ? Theme.fmt(row.track.durationMs) : ""
            color: Theme.dim
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }
    }

    NMenu {
        id: menu
        MenuItem { text: "Putar"; onTriggered: row.play() }
        MenuItem { text: "Putar radio dari lagu ini"; onTriggered: player.playRadio(row.track.uri) }
        MenuItem { text: "Tambah ke antrean"; onTriggered: player.addToQueue(row.track.uri) }
        MenuItem {
            text: row.liked ? "Hapus dari Lagu Disukai" : "Simpan ke Lagu Disukai"
            onTriggered: player.setLiked(row.track.uri, !row.liked)
        }
        NMenu {
            id: addMenu
            title: "Tambah ke playlist"
            MenuItem { text: "+ Playlist baru…"; onTriggered: Nav.newPlaylist([row.track]) }
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
            visible: row.imported
            height: visible ? implicitHeight : 0
            text: "Pilih versi lain…"
            onTriggered: Nav.matchPicker(row.track)
        }
        MenuItem {
            visible: row.removable
            height: visible ? implicitHeight : 0
            text: "Hapus dari playlist ini"
            onTriggered: row.remove()
        }
        MenuItem { text: "Buka album"; enabled: !!row.track.albumId; onTriggered: Nav.go("album", row.track.albumId) }
        MenuItem { text: "Buka artis"; enabled: !!row.track.artistId; onTriggered: Nav.go("artist", row.track.artistId) }
        MenuItem {
            text: "Salin link lagu"
            onTriggered: session.copy(row.isYouTube ? "https://music.youtube.com/watch?v=" + row.track.id
                                                    : "https://open.spotify.com/track/" + row.track.id)
        }
    }
}
