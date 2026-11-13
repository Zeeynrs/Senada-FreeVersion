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
                    Label { text: I18n.t("Library"); font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }
                    Label {
                        text: I18n.n("{n} playlist", "{n} playlists", library.ownPlaylists.length) + " • "
                              + I18n.t("{n} saved", { n: library.playlists.length - library.ownPlaylists.length }) + " • "
                              + I18n.t("all on this device")
                        color: Theme.dim
                        font.pixelSize: 14
                    }
                }
                NButton { text: I18n.t("New playlist"); iconName: "queue-add"; primary: true; onClicked: Nav.newPlaylist([]) }
                NButton { text: I18n.t("Import playlist"); iconName: "download"; onClicked: importBox.visible = !importBox.visible }
            }

            // inline import (Spotify or YouTube Music link)
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
                        placeholderText: I18n.t("Paste a playlist or album link from Spotify or YouTube Music")
                        onAccepted: importBtn.clicked()
                    }
                    NButton {
                        id: importBtn
                        text: I18n.t("Import")
                        primary: true
                        enabled: importField.text.trim().length > 0
                        onClicked: { library.importLink(importField.text.trim()); importField.text = ""; importBox.visible = false }
                    }
                }
            }

            Row {
                spacing: 8
                Repeater {
                    model: [
                        { key: "all", label: I18n.t("All") },
                        { key: "playlist", label: I18n.t("Playlists") },
                        { key: "album", label: I18n.t("Albums") },
                        { key: "artist", label: I18n.t("Artists") },
                        { key: "imported", label: I18n.t("Imported") }
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
                                    tip: I18n.t("Play liked songs")
                                    onClicked: player.playContext("senada:liked:", "")
                                }
                            }
                            Item { width: 1; height: 8 }
                            Label { width: parent.width; text: I18n.t("Liked Songs"); elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Bold }
                            Label {
                                width: parent.width
                                text: I18n.t("Playlist") + " • " + I18n.n("{n} song", "{n} songs", (library.likedRevision, library.likedCount))
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
                text: page.filter === "playlist" || page.filter === "imported" ? I18n.t("No playlists here yet. Click “New playlist” or “Import playlist”.")
                                            : I18n.t("Nothing saved yet. Tap ♡ on an album, playlist or artist page.")
                color: Theme.dim
                font.pixelSize: 15
            }
        }
    }
}
