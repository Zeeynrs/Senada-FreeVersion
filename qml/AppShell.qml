import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: shell
    objectName: "shell"
    property bool immersive: false
    property bool sidebarOpen: true
    property string panel: "lyrics"   // right panel: "lyrics" | "queue" | "" (closed)
    // the player bar as a rounded card floating above the bottom edge (Settings → Appearance)
    readonly property bool floatingBar: session.playerBarStyle === "floating"
    property var forwardStack: []     // pages left with "back", for "forward"

    readonly property string currentKey: stack.currentItem ? stack.currentItem.pageKey : ""
    readonly property string libraryFilter: currentKey === "library" ? stack.currentItem.filter : ""
    // these replace each other instead of piling up
    readonly property var topLevel: ["search", "library", "liked", "offline"]

    function entryOf(item) {
        if (!item) return null
        const key = item.pageKey
        if (key === "library") return { kind: "library", itemId: item.filter }
        const i = key.indexOf(":")
        return i < 0 ? { kind: key, itemId: "" } : { kind: key.slice(0, i), itemId: key.slice(i + 1) }
    }

    function navigate(kind, itemId, keepForward) {
        if (!kind) return
        itemId = itemId || ""
        // Settings is a dialog over the page: the Settings button (and Ctrl+,) toggles it
        if (kind === "settings") {
            if (settingsDialog.opened && (!itemId || itemId === settingsDialog.section))
                settingsDialog.close()
            else
                settingsDialog.openAt(itemId)
            return
        }
        if (settingsDialog.visible)
            settingsDialog.close()
        immersive = false
        if (!keepForward) forwardStack = []
        if (kind === "home") {
            stack.pop(null)
            return
        }
        // library sections: switch the filter of the open library page
        if (kind === "library" && currentKey === "library") {
            stack.currentItem.filter = itemId || "all"
            return
        }
        const key = kind + ":" + itemId
        const standalone = kind === "liked" || kind === "offline" || topLevel.indexOf(kind) >= 0
        if (currentKey === key || currentKey === kind || (!standalone && !itemId))
            return
        if (topLevel.indexOf(kind) >= 0 && stack.depth > 1)
            stack.pop(null, StackView.Immediate)
        if (kind === "playlist" || kind === "album" || kind === "liked" || kind === "offline")
            stack.push(collectionComp, { kind: kind, itemId: itemId })
        else if (kind === "artist")
            stack.push(artistComp, { itemId: itemId })
        else if (kind === "search")
            stack.push(searchComp)
        else if (kind === "library")
            stack.push(libraryComp, { filter: itemId || "all" })
    }

    function goBack() {
        if (immersive) { immersive = false; return }
        if (stack.depth <= 1) return
        const e = entryOf(stack.currentItem)
        if (e) forwardStack = forwardStack.concat([e])
        stack.pop()
    }
    function goForward() {
        if (forwardStack.length === 0) return
        const e = forwardStack[forwardStack.length - 1]
        forwardStack = forwardStack.slice(0, -1)
        navigate(e.kind, e.itemId, true)
    }
    function togglePanel(name) {
        panel = panel === name ? "" : name
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
        function onShareLyrics(index) { shareLyricsDialog.openAt(index) }
        function onImmersive(on) { shell.immersive = on }
    }
    MatchPicker { id: matchPicker }
    ShareLyricsDialog { id: shareLyricsDialog }
    SettingsDialog { id: settingsDialog }

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
            radius: 16
            color: Theme.surface2
            border.color: Theme.line
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

        contentItem: ColumnLayout {
            spacing: 16
            Label {
                text: playlistDialog.mode === "create" ? I18n.t("New playlist")
                    : playlistDialog.mode === "rename" ? I18n.t("Rename playlist") : I18n.t("Delete playlist?")
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Label {
                visible: playlistDialog.mode === "delete"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.dim
                text: I18n.t("“{name}” will be removed from this device. Its songs stay on YouTube Music.", { name: playlistDialog.currentName })
            }
            NTextField {
                id: nameField
                visible: playlistDialog.mode !== "delete"
                Layout.fillWidth: true
                placeholderText: I18n.t("Playlist name")
                onAccepted: playlistDialog.accept()
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                NButton { text: I18n.t("Cancel"); onClicked: playlistDialog.close() }
                NButton {
                    primary: true
                    text: playlistDialog.mode === "create" ? I18n.t("Create") : playlistDialog.mode === "rename" ? I18n.t("Save") : I18n.t("Delete")
                    enabled: playlistDialog.mode === "delete" || nameField.text.trim().length > 0
                    onClicked: playlistDialog.accept()
                }
            }
        }
    }

    // ---- glass backdrop ----------------------------------------------------------------
    // "Sampul album": the current cover, heavily blurred, fills the window behind the
    // translucent panels. ("Transparan" leaves the window itself see-through instead.)
    Item {
        anchors.fill: parent
        visible: Theme.glassMode === "cover"
        Image {
            id: glassArt
            anchors.fill: parent
            source: player.state.image || ""
            sourceSize: Qt.size(192, 192)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: glassArt
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.35
            brightness: Theme.dark ? -0.1 : 0.15
            scale: 1.2
            opacity: glassArt.status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
    }

    // content background (translucent in the glass modes)
    Rectangle {
        anchors.fill: content
        color: Theme.bg
    }
    // "vivid" accent: a soft glow of the accent colour at the top of the pages
    Rectangle {
        anchors.left: content.left
        anchors.right: content.right
        anchors.top: content.top
        height: Math.min(380, content.height * 0.6)
        opacity: Theme.glowOn ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.glow }
            GradientStop { position: 0.55; color: Theme.alpha(Theme.glow, Theme.glow.a * 0.35) }
            GradientStop { position: 1; color: Theme.alpha(Theme.glow, 0) }
        }
    }

    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        canGoBack: stack.depth > 1
        canGoForward: shell.forwardStack.length > 0
        sidebarOpen: shell.sidebarOpen
        panel: shell.panel
        onToggleSidebar: shell.sidebarOpen = !shell.sidebarOpen
        onBack: shell.goBack()
        onForward: shell.goForward()
        onTogglePanel: shell.panel = shell.panel !== "" ? "" : "lyrics"
    }

    Sidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: topBar.bottom
        anchors.bottom: playerBar.top
        anchors.bottomMargin: shell.floatingBar ? 12 : 0
        width: shell.sidebarOpen ? Theme.sidebarWidth : 0
        visible: width > 0
        currentKey: shell.currentKey
        settingsOpen: settingsDialog.visible
        libraryFilter: shell.libraryFilter
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    RightPanel {
        id: rightPanel
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: playerBar.top
        anchors.bottomMargin: shell.floatingBar ? 12 : 0
        width: shell.panel !== "" ? Math.min(Theme.rightPanelWidth, shell.width * 0.3) : 0
        visible: width > 0
        panel: shell.panel || "lyrics"
        onSelect: (name) => shell.panel = name
        onClose: shell.panel = ""
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Item {
        id: content
        anchors.top: topBar.bottom
        anchors.left: sidebar.right
        anchors.right: rightPanel.left
        anchors.bottom: playerBar.top
        anchors.bottomMargin: shell.floatingBar ? 12 : 0
        clip: true

        StackView {
            id: stack
            anchors.fill: parent
            initialItem: HomePage {}

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                    NumberAnimation { property: "y"; from: 16; to: 0; duration: 240; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 } }
            popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 }
                    NumberAnimation { property: "y"; from: 0; to: 16; duration: 180 }
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
            radius: 14
            color: Theme.surface2
            border.width: 1
            border.color: Theme.lineStrong
            z: 20

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                Icon { glyph: "download"; size: 20; color: Theme.text }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        Layout.fillWidth: true
                        text: updater.bannerTitle
                        font.pixelSize: 13
                        font.weight: Font.Bold
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
                    text: !updater.updating ? I18n.t("Update")
                          : updater.releaseMode && updater.progress >= 0 ? updater.progress + "%" : I18n.t("Updating…")
                    primary: true
                    enabled: !updater.updating
                    onClicked: updater.applyUpdate()
                }

                IconButton {
                    iconName: "close"
                    size: 16
                    tip: I18n.t("Hide")
                    onClicked: updater.dismissBanner()
                }
            }
        }
    }

    RectangularShadow {
        anchors.fill: playerBar
        visible: shell.floatingBar
        radius: playerBar.radius
        blur: 36
        offset.y: 10
        // on the light theme a shadow of the song's colour, which reads softer than grey
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.6) : Theme.alpha(Theme.mix(Theme.accent, Qt.rgba(0, 0, 0, 1), 0.55), 0.22)
    }
    PlayerBar {
        id: playerBar
        floating: shell.floatingBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: floating ? 18 : 0
        anchors.rightMargin: floating ? 18 : 0
        anchors.bottomMargin: floating ? 14 : 0
        panel: shell.panel
        onOpenImmersive: shell.immersive = true
        onShowPanel: (name) => shell.togglePanel(name)
        onOpenMiniPlayer: shell.Window.window.enterMiniPlayer()
    }

    // mouse "back" button
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: shell.goBack()
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
        value: (shell.immersive && session.visualizerEnabled && shell.Window.visibility !== Window.Minimized)
               || (!!shell.Window.window && shell.Window.window.miniMode && session.islandStyle === "wave")
    }

    // the artist of a song without an artist id, found by name (Nav.goArtist)
    Connections {
        target: Nav
        function onFindArtist(names) { library.findArtist(names) }
    }
    Connections {
        target: library
        function onArtistFound(artistId) { Nav.go("artist", artistId) }
    }

    Component { id: collectionComp; CollectionPage {} }
    Component { id: artistComp; ArtistPage {} }
    Component { id: searchComp; SearchPage {} }
    Component { id: libraryComp; LibraryPage {} }

    Shortcut { sequence: "Space"; onActivated: player.togglePlay() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: player.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: player.previous() }
    Shortcut { sequence: "Ctrl+Up"; onActivated: player.setVolume(Math.min(100, (player.state.volume || 0) + 5)) }
    Shortcut { sequence: "Ctrl+Down"; onActivated: player.setVolume(Math.max(0, (player.state.volume || 0) - 5)) }
    Shortcut { sequence: "Ctrl+F"; onActivated: Nav.go("search") }
    Shortcut { sequence: "Ctrl+L"; onActivated: shell.immersive = !shell.immersive }
    Shortcut { sequence: "Ctrl+,"; onActivated: Nav.go("settings") }
    Shortcut { sequence: "Ctrl+Q"; onActivated: session.quit() }
    Shortcut { sequence: "Alt+Left"; onActivated: shell.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: shell.goForward() }
    Shortcut { sequence: "Ctrl+B"; onActivated: shell.sidebarOpen = !shell.sidebarOpen }
    Shortcut { sequence: "Ctrl+M"; onActivated: shell.Window.window.enterMiniPlayer() }
    Shortcut {
        sequence: "Escape"
        onActivated: settingsDialog.visible ? settingsDialog.close() : shell.goBack()
    }
}
