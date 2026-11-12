import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: shell
    objectName: "shell"
    property bool immersive: false

    readonly property string currentKey: stack.currentItem ? stack.currentItem.pageKey : ""
    readonly property var topLevel: ["search", "library", "settings"]

    function navigate(kind, itemId) {
        const key = kind + ":" + itemId
        const cur = currentKey
        immersive = false
        if (kind === "home") {
            stack.pop(null)
            return
        }
        const standalone = kind === "liked" || topLevel.indexOf(kind) >= 0
        if (cur === key || cur === kind || !kind || (!standalone && !itemId))
            return
        // dock destinations replace each other instead of piling up
        if (topLevel.indexOf(kind) >= 0 && stack.depth > 1)
            stack.pop(null, StackView.Immediate)
        if (kind === "playlist" || kind === "album" || kind === "liked")
            stack.push(collectionComp, { kind: kind, itemId: itemId })
        else if (kind === "artist")
            stack.push(artistComp, { itemId: itemId })
        else if (kind === "search")
            stack.push(searchComp)
        else if (kind === "library")
            stack.push(libraryComp)
        else if (kind === "settings")
            stack.push(settingsComp)
    }

    Connections {
        target: Nav
        function onOpen(kind, itemId) { shell.navigate(kind, itemId) }
        function onPlaylistDialog(mode, playlistId, currentName, tracks) {
            playlistDialog.mode = mode
            playlistDialog.playlistId = playlistId
            playlistDialog.tracks = tracks || []
            nameField.text = mode === "create" ? "" : currentName
            playlistDialog.currentName = currentName
            playlistDialog.open()
        }
    }

    Connections {
        target: library
        function onPlaylistCreated(pid) { shell.navigate("playlist", pid) }
    }

    Connections {
        target: Nav
        function onMatchPicker(track) { matchPicker.openFor(track) }
    }
    MatchPicker { id: matchPicker }

    // create / rename / delete an own playlist
    Popup {
        id: playlistDialog
        property string mode: "create"
        property string playlistId
        property string currentName
        property var tracks: []
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(420, shell.width - 48)
        modal: true
        focus: true
        padding: 24
        onOpened: if (mode !== "delete") nameField.forceActiveFocus()

        function accept() {
            if (mode === "delete") {
                library.deletePlaylist(playlistId)
                const cur = stack.currentItem ? stack.currentItem.pageKey : ""
                if (cur === "playlist:" + playlistId) stack.pop()
            } else if (nameField.text.trim().length > 0) {
                if (mode === "create") {
                    const pid = library.createPlaylist(nameField.text.trim(), tracks)
                    if (tracks.length === 0) shell.navigate("playlist", pid)
                } else {
                    library.renamePlaylist(playlistId, nameField.text.trim())
                }
            } else {
                return
            }
            close()
        }

        background: Rectangle {
            radius: 22
            color: Theme.surface2
            border.color: Theme.alpha(Theme.text, 0.08)
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

        contentItem: ColumnLayout {
            spacing: 16
            Label {
                text: playlistDialog.mode === "create" ? "Playlist baru"
                    : playlistDialog.mode === "rename" ? "Ganti nama playlist" : "Hapus playlist?"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Label {
                visible: playlistDialog.mode === "delete"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.dim
                text: "“" + playlistDialog.currentName + "” akan dihapus dari perangkat ini. Lagu-lagunya tetap ada di YouTube Music."
            }
            NTextField {
                id: nameField
                visible: playlistDialog.mode !== "delete"
                Layout.fillWidth: true
                placeholderText: "Nama playlist"
                onAccepted: playlistDialog.accept()
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                NButton { text: "Batal"; onClicked: playlistDialog.close() }
                NButton {
                    primary: true
                    text: playlistDialog.mode === "create" ? "Buat" : playlistDialog.mode === "rename" ? "Simpan" : "Hapus"
                    enabled: playlistDialog.mode === "delete" || nameField.text.trim().length > 0
                    onClicked: playlistDialog.accept()
                }
            }
        }
    }

    Ambient {
        anchors.fill: parent
        art: player.state.image || ""
    }

    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        currentKey: shell.currentKey
        canGoBack: stack.depth > 1
        onBack: stack.pop()
    }

    Item {
        id: content
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

                StackView {
                    id: stack
                    anchors.fill: parent
                    initialItem: HomePage {}

                    pushEnter: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                            NumberAnimation { property: "y"; from: 24; to: 0; duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                    pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 } }
                    popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 } }
                    popExit: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 }
                            NumberAnimation { property: "y"; from: 0; to: 24; duration: 200 }
                        }
                    }
                }

                Rectangle {
                    id: updateBanner
                    visible: opacity > 0
                    opacity: updater.bannerVisible ? 1 : 0
                    anchors.top: parent.top
                    anchors.topMargin: updater.bannerVisible ? 14 : -70
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    width: Math.min(480, parent.width - 90)
                    height: 58
                    radius: 18
                    color: Theme.surface2
                    border.width: 1
                    border.color: Theme.alpha(Theme.mint, 0.4)
                    z: 20

                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on anchors.topMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 17
                            color: Theme.alpha(Theme.mint, 0.16)
                            Icon {
                                anchors.centerIn: parent
                                glyph: "download"
                                size: 18
                                color: Theme.mint
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: "Update GitHub tersedia (" + updater.commitsBehind + " commit)"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: updater.remoteMessage
                                font.pixelSize: 12
                                color: Theme.dim
                                elide: Text.ElideRight
                            }
                        }

                        NButton {
                            text: updater.updating ? "Memperbarui…" : "Perbarui"
                            primary: true
                            enabled: !updater.updating
                            onClicked: updater.applyUpdate()
                        }

                        IconButton {
                            iconName: "close"
                            size: 16
                            tip: "Sembunyikan"
                            onClicked: updater.dismissBanner()
                        }
                    }
                }
    }

    // content fades out before it slides under the dock
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 150
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.75; color: Theme.alpha(Theme.bg, 0.82) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.bg, 0.92) }
        }
    }

    BloomDock {
        id: dock
        width: Math.min(1040, shell.width - 40)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        currentKey: shell.currentKey
        onOpenImmersive: shell.immersive = true
    }

    // mouse "back" button
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: if (stack.depth > 1) stack.pop()
    }

    ImmersivePlayer {
        id: immersivePlayer
        width: shell.width
        height: shell.height
        open: shell.immersive
        onClose: shell.immersive = false
    }

    Binding {
        target: visualizer
        property: "active"
        value: shell.immersive && session.visualizerEnabled && shell.Window.visibility !== Window.Minimized
    }

    Component { id: collectionComp; CollectionPage {} }
    Component { id: artistComp; ArtistPage {} }
    Component { id: searchComp; SearchPage {} }
    Component { id: libraryComp; LibraryPage {} }
    Component { id: settingsComp; SettingsPage {} }

    Shortcut { sequence: "Space"; onActivated: player.togglePlay() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: player.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: player.previous() }
    Shortcut { sequence: "Ctrl+Up"; onActivated: player.setVolume(Math.min(100, (player.state.volume || 0) + 5)) }
    Shortcut { sequence: "Ctrl+Down"; onActivated: player.setVolume(Math.max(0, (player.state.volume || 0) - 5)) }
    Shortcut { sequence: "Ctrl+F"; onActivated: Nav.go("search") }
    Shortcut { sequence: "Ctrl+L"; onActivated: shell.immersive = !shell.immersive }
    Shortcut { sequence: "Ctrl+,"; onActivated: Nav.go("settings") }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Alt+Left"; onActivated: if (stack.depth > 1) stack.pop() }
    Shortcut {
        sequence: "Escape"
        onActivated: shell.immersive ? shell.immersive = false : (stack.depth > 1 ? stack.pop() : null)
    }
}
