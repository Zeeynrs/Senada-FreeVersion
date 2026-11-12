import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Everything kept on this device: liked songs, own playlists, saved albums/playlists/artists.
Item {
    id: page
    readonly property string pageKey: "library"
    property string filter: "all"  // all | playlist | album | artist | imported

    readonly property var items: library.playlists.filter(p =>
        filter === "all" ? true
        : filter === "imported" ? !!p.imported
        : p.kind === filter)
    readonly property int columns: Math.max(2, Math.floor((flick.width - 48 + 8) / 200))

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
            spacing: 20

            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true
                    Label { text: "Koleksi"; font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }
                    Label {
                        text: library.ownPlaylists.length + " playlist • " + (library.playlists.length - library.ownPlaylists.length)
                              + " tersimpan • semuanya di perangkat ini"
                        color: Theme.dim
                        font.pixelSize: 14
                    }
                }
                NButton { text: "Playlist baru"; iconName: "queue-add"; primary: true; onClicked: Nav.newPlaylist([]) }
                NButton { text: "Impor Spotify"; iconName: "download"; onClicked: importBox.visible = !importBox.visible }
            }

            // inline Spotify import
            Rectangle {
                id: importBox
                visible: false
                width: parent.width
                implicitHeight: importRow.implicitHeight + 32
                radius: 16
                color: Theme.surface
                border.color: Theme.line
                RowLayout {
                    id: importRow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    NTextField {
                        id: importField
                        Layout.fillWidth: true
                        iconName: "download"
                        placeholderText: "Tempel link playlist/album publik Spotify (open.spotify.com/playlist/…)"
                        onAccepted: importBtn.clicked()
                    }
                    NButton {
                        id: importBtn
                        text: "Impor"
                        primary: true
                        enabled: importField.text.trim().length > 0
                        onClicked: { library.importSpotify(importField.text.trim()); importField.text = ""; importBox.visible = false }
                    }
                }
            }

            Row {
                spacing: 8
                Repeater {
                    model: [
                        { key: "all", label: "Semua" },
                        { key: "playlist", label: "Playlist" },
                        { key: "album", label: "Album" },
                        { key: "artist", label: "Artis" },
                        { key: "imported", label: "Impor" }
                    ]
                    Chip {
                        text: modelData.label
                        checked: page.filter === modelData.key
                        onClicked: page.filter = modelData.key
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8

                // liked songs: same outlined card shape, with a heart instead of a cover
                AbstractButton {
                    id: likedTile
                    visible: page.filter === "all" || page.filter === "playlist"
                    width: (parent.width - 8 * (page.columns - 1)) / page.columns
                    height: likedCard.implicitHeight + 26
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    onClicked: Nav.go("liked")
                    background: Item {}
                    contentItem: Item {
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 16
                            color: likedTile.hovered ? Theme.hover : "transparent"
                            border.color: likedTile.hovered ? Theme.lineStrong : Theme.line
                        }
                        Column {
                            id: likedCard
                            x: 12; y: 12
                            width: parent.width - 24
                            spacing: 3
                            Rectangle {
                                width: parent.width
                                height: width
                                radius: 10
                                color: Theme.surface3
                                Icon { anchors.centerIn: parent; glyph: "heart"; size: parent.width * 0.32; color: Theme.like }
                                IconButton {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    visible: likedTile.hovered && library.likedCount > 0
                                    iconName: "play"
                                    size: 20
                                    filled: true
                                    tip: "Putar lagu yang disukai"
                                    onClicked: player.playContext("senada:liked:", "")
                                }
                            }
                            Item { width: 1; height: 8 }
                            Label { width: parent.width; text: "Lagu yang Disukai"; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Bold }
                            Label {
                                width: parent.width
                                text: "Playlist • " + (library.likedRevision, library.likedCount) + " lagu"
                                color: Theme.dim
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                Repeater {
                    model: page.items
                    Card {
                        width: (parent.width - 8 * (page.columns - 1)) / page.columns
                        item: modelData
                    }
                }
            }

            Label {
                visible: page.items.length === 0 && page.filter !== "all"
                x: 12
                text: page.filter === "playlist" || page.filter === "imported" ? "Belum ada playlist di sini. Klik “Playlist baru” atau “Impor Spotify”."
                                            : "Belum ada yang disimpan. Tekan ♡ di halaman album, playlist, atau artis."
                color: Theme.dim
                font.pixelSize: 15
            }
        }
    }
}
