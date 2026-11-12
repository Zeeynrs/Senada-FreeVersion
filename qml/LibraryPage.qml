import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Everything kept on this device: liked songs, own playlists, saved albums/playlists/artists.
Item {
    id: page
    readonly property string pageKey: "library"
    property string filter: "all"  // all | own | album | playlist | artist

    readonly property var items: library.playlists.filter(p =>
        filter === "all" ? true
        : filter === "own" ? !!p.local
        : filter === "playlist" ? (p.kind === "playlist" && !p.local)
        : p.kind === filter)
    readonly property int columns: Math.max(2, Math.floor((flick.width - 48 + 8) / 200))

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
            spacing: 22

            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Label { text: "Library"; font.pixelSize: 44; font.weight: Font.Black; font.letterSpacing: -1.2 }
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
                radius: 28
                color: Theme.glass
                border.color: Theme.glassBorder
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
                        { key: "own", label: "Playlist Saya" },
                        { key: "album", label: "Album" },
                        { key: "playlist", label: "Playlist" },
                        { key: "artist", label: "Artis" }
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

                // liked songs: a big fuchsia bloom tile
                AbstractButton {
                    id: likedTile
                    visible: page.filter === "all"
                    width: Math.min(parent.width, (parent.width - 8 * (page.columns - 1)) / page.columns * 2 + 8)
                    height: (parent.width - 8 * (page.columns - 1)) / page.columns + 58
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    clip: true
                    onClicked: Nav.go("liked")
                    background: Rectangle {
                        radius: 30
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.alpha(Theme.fuchsia, likedTile.hovered ? 0.42 : 0.32) }
                            GradientStop { position: 1; color: Theme.alpha(Theme.mint, likedTile.hovered ? 0.16 : 0.1) }
                        }
                        border.color: Theme.glassBorder
                    }
                    contentItem: Item {
                        Scallop {
                            width: parent.height * 0.95; height: width
                            x: parent.width - width * 0.72
                            y: -height * 0.18
                            lobes: 14; depth: 0.1
                            color: Theme.alpha(Theme.fuchsia, 0.35)
                            rotation: likedTile.hovered ? 25 : 0
                            Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 24
                            spacing: 4
                            Icon { glyph: "heart"; size: 30; color: Theme.text }
                            Label { text: "Lagu yang Disukai"; font.pixelSize: 26; font.weight: Font.Black }
                            Label {
                                text: (library.likedRevision, library.likedCount) + " lagu"
                                color: Theme.text
                                opacity: 0.8
                                font.pixelSize: 14
                            }
                        }
                        BloomPlayButton {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            size: 52
                            visible: library.likedCount > 0
                            tip: "Putar lagu yang disukai"
                            onClicked: player.playContext("senada:liked:", "")
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
                text: page.filter === "own" ? "Belum ada playlist. Klik “Playlist baru” atau impor dari Spotify."
                                            : "Belum ada yang disimpan. Tekan ♡ di halaman album, playlist, atau artis."
                color: Theme.dim
                font.pixelSize: 15
            }
        }
    }
}
