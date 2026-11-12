import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Left navigation: Home, Search, the expandable "Koleksimu" (library sections),
// Settings, then everything kept in the library with its cover.
Rectangle {
    id: side
    property string currentKey
    property string libraryFilter   // filter of the open library page, "" otherwise
    property bool libraryOpen: true
    color: Theme.sidebar
    implicitWidth: Theme.sidebarWidth
    clip: true

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    // one navigation entry
    component NavEntry: AbstractButton {
        id: e
        property string iconName
        property bool current: false
        property bool sub: false       // indented library section
        property string trailing: ""   // "expand-more" / "chevron-right"
        Layout.fillWidth: true
        implicitHeight: sub ? 34 : 38
        hoverEnabled: true
        focusPolicy: Qt.TabFocus
        background: Rectangle {
            radius: 8
            color: e.current ? Theme.hover : e.hovered ? Theme.subtle : "transparent"
            border.width: e.visualFocus ? 1 : 0
            border.color: Theme.lineStrong
        }
        contentItem: RowLayout {
            spacing: 12
            Icon {
                visible: !e.sub
                Layout.leftMargin: 10
                glyph: e.iconName
                size: 18
                color: e.current || e.hovered ? Theme.text : Theme.dim
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: e.sub ? 30 : 0
                text: e.text
                elide: Text.ElideRight
                font.pixelSize: 14
                font.weight: e.current ? Font.DemiBold : Font.Normal
                color: e.current || e.hovered ? Theme.text : Theme.dim
            }
            Icon {
                visible: e.trailing !== ""
                Layout.rightMargin: 8
                glyph: e.trailing || "chevron-right"
                size: 16
                color: Theme.faint
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 11
        spacing: 2

        NavEntry { text: I18n.t("Home"); iconName: "home"; current: side.currentKey === "home"; onClicked: Nav.go("home") }
        NavEntry { text: I18n.t("Search"); iconName: "search"; current: side.currentKey === "search"; onClicked: Nav.go("search") }
        NavEntry {
            text: I18n.t("Your Library")
            iconName: "library"
            trailing: side.libraryOpen ? "expand-more" : "chevron-right"
            current: side.currentKey === "library" && side.libraryFilter === "all"
            onClicked: {
                if (side.currentKey === "library" && side.libraryFilter === "all") side.libraryOpen = !side.libraryOpen
                else { side.libraryOpen = true; Nav.go("library", "all") }
            }
        }
        // library sections, with a guide line like a tree
        Item {
            Layout.fillWidth: true
            implicitHeight: side.libraryOpen ? subCol.implicitHeight : 0
            visible: implicitHeight > 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Rectangle { x: 19; width: 1; height: subCol.implicitHeight - 6; y: 3; color: Theme.line }
            ColumnLayout {
                id: subCol
                width: parent.width
                spacing: 0
                NavEntry { sub: true; text: I18n.t("Liked songs"); current: side.currentKey === "liked:"; onClicked: Nav.go("liked") }
                NavEntry { sub: true; text: I18n.t("Albums"); current: side.libraryFilter === "album"; onClicked: Nav.go("library", "album") }
                NavEntry { sub: true; text: I18n.t("Artists"); current: side.libraryFilter === "artist"; onClicked: Nav.go("library", "artist") }
                NavEntry { sub: true; text: I18n.t("Playlists"); current: side.libraryFilter === "playlist"; onClicked: Nav.go("library", "playlist") }
                NavEntry { sub: true; text: I18n.t("Imported"); current: side.libraryFilter === "imported"; onClicked: Nav.go("library", "imported") }
            }
        }
        NavEntry {
            text: I18n.t("Settings")
            iconName: "settings"
            trailing: "chevron-right"
            current: side.currentKey === "settings"
            onClicked: Nav.go("settings")
        }

        // update waiting on GitHub
        AbstractButton {
            id: upd
            visible: updater.updateAvailable
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 36
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            enabled: !updater.updating
            onClicked: updater.applyUpdate()
            background: Rectangle {
                radius: 8
                color: upd.hovered ? Theme.hover : "transparent"
                border.color: Theme.lineStrong
            }
            contentItem: RowLayout {
                spacing: 12
                Icon { Layout.leftMargin: 10; glyph: "download"; size: 18; color: Theme.text }
                Label {
                    Layout.fillWidth: true
                    text: updater.badgeText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            ToolTip.visible: hovered && updater.remoteMessage !== ""
            ToolTip.text: updater.remoteMessage
            ToolTip.delay: 400
        }

        // saved items header
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.leftMargin: 8
            Label {
                Layout.fillWidth: true
                text: I18n.t("SAVED")
                color: Theme.faint
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
            IconButton {
                iconName: "add"
                size: 16
                tint: Theme.dim
                tip: I18n.t("New playlist")
                onClicked: Nav.newPlaylist([])
            }
        }

        ListView {
            id: savedList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: library.playlists
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: NScrollBar {}
            SmoothScroll { flickable: savedList }

            delegate: AbstractButton {
                id: it
                required property var modelData
                readonly property bool current: side.currentKey === modelData.kind + ":" + modelData.id
                width: savedList.width
                implicitHeight: 52
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                onClicked: Nav.go(modelData.kind, modelData.id)
                background: Rectangle {
                    radius: 8
                    color: it.current ? Theme.hover : it.hovered ? Theme.subtle : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 10
                    Cover {
                        Layout.leftMargin: 6
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 5
                        round: it.modelData.kind === "artist"
                        simple: true
                        source: it.modelData.imageSmall || ""
                        fallbackIcon: it.modelData.kind === "artist" ? "person" : it.modelData.kind === "album" ? "album" : "list"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: it.modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.weight: it.current ? Font.DemiBold : Font.Normal
                        }
                        Label {
                            Layout.fillWidth: true
                            text: it.modelData.local ? (it.modelData.imported ? I18n.t("Imported playlist") : I18n.t("Playlist"))
                                 : it.modelData.kind === "album" ? I18n.t("Album") : it.modelData.kind === "artist" ? I18n.t("Artist") : I18n.t("Playlist")
                            color: Theme.dim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: if (it.modelData.local) itMenu.popup() }
                NMenu {
                    id: itMenu
                    MenuItem { text: I18n.t("Play"); onTriggered: player.playContext(it.modelData.uri, "") }
                    MenuItem { text: I18n.t("Rename…"); onTriggered: Nav.renamePlaylist(it.modelData.id, it.modelData.name) }
                    MenuItem { text: I18n.t("Delete…"); onTriggered: Nav.deletePlaylist(it.modelData.id, it.modelData.name) }
                }
            }

            Label {
                visible: savedList.count === 0
                width: savedList.width
                leftPadding: 8
                rightPadding: 8
                topPadding: 4
                text: I18n.t("Your playlists, and the albums, artists and playlists you save (♡), show up here.")
                wrapMode: Text.WordWrap
                color: Theme.faint
                font.pixelSize: 12
            }
        }
    }
}
