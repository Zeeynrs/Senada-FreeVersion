import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Cover + title block used by playlist, album, liked and artist pages.
Item {
    id: h
    property var info: ({})
    property bool loading: false
    property bool round: false
    property string fallbackIcon: "note"
    // library actions
    property bool canSave: false     // catalog album/playlist/artist: heart = keep in the library
    property bool saved: false
    property bool canImport: false   // public Spotify page: copy into an own playlist
    property bool isLocal: false     // own playlist: rename / delete
    // the player is playing this collection right now (the pill becomes "Jeda")
    readonly property bool nowPlaying: !!player.state.contextUri
                                       && (player.state.contextUri === h.info.playUri || player.state.contextUri === h.info.uri)
    signal playAll()
    signal shuffleAll()
    signal saveToggled()
    signal importRequested()
    signal renameRequested()
    signal deleteRequested()

    readonly property url art: h.info.imageLarge || h.info.image || ""
    readonly property real coverSide: Math.min(208, Math.max(140, h.width * 0.2))

    // cover and text are bottom-aligned; the taller of the two sets the height
    readonly property real rowHeight: Math.max(h.coverSide, textCol.implicitHeight)
    implicitHeight: rowHeight + 16 + 40

    Item {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 16
        height: h.rowHeight

        Item {
            id: coverBox
            width: h.coverSide
            height: h.coverSide
            y: h.rowHeight - height

            Cover {
                anchors.fill: parent
                radius: 12
                round: h.round
                source: h.art
                fallbackIcon: h.fallbackIcon
            }
        }

        ColumnLayout {
            id: textCol
            x: coverBox.width + 32
            width: row.width - x
            y: h.rowHeight - implicitHeight
            spacing: 8

            Label {
                visible: text !== ""
                text: (h.info.typeLabel || (h.round ? "Artis" : "")).toUpperCase()
                color: Theme.dim
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }
            Label {
                Layout.fillWidth: true
                text: h.loading && !h.info.name ? "Memuat…" : (h.info.name || "")
                font.pixelSize: Math.max(30, Math.min(56, h.width / 16))
                font.weight: Font.Black
                font.letterSpacing: -0.8
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                lineHeight: 0.92
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: h.info.description || h.info.genres || ""
                textFormat: Text.PlainText
                color: Theme.dim
                font.pixelSize: 14
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
            Label {
                text: h.info.kind === "playlist"
                      ? (h.info.subtitle || "") + (h.info.tracks ? " • " + h.info.tracks.length + " lagu" : "")
                      : h.info.kind === "artist" ? "" : (h.info.subtitle || "")
                visible: text !== ""
                font.pixelSize: 13
                color: Theme.dim
            }

            Row {
                Layout.topMargin: 12
                spacing: 8
                // play / pause pill
                AbstractButton {
                    id: playPill
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool pausable: h.nowPlaying && player.state.isPlaying === true
                    enabled: !h.loading && (!!h.info.playUri || (h.info.tracks && h.info.tracks.length > 0))
                    opacity: enabled ? 1 : 0.4
                    implicitHeight: 40
                    implicitWidth: pillRow.implicitWidth + 32
                    hoverEnabled: true
                    focusPolicy: Qt.TabFocus
                    onClicked: h.nowPlaying ? player.togglePlay() : h.playAll()
                    background: Rectangle {
                        radius: 10
                        color: playPill.down ? Theme.alpha(Theme.primary, 0.8) : playPill.hovered ? Theme.alpha(Theme.primary, 0.9) : Theme.primary
                    }
                    contentItem: Item {
                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: playPill.pausable ? "pause" : "play"
                                size: 18
                                color: Theme.primaryText
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: playPill.pausable ? "Jeda" : "Putar"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.primaryText
                            }
                        }
                    }
                }
                SquareButton {
                    iconName: "shuffle"
                    tip: "Putar acak"
                    enabled: !h.loading
                    onClicked: h.shuffleAll()
                }
                SquareButton {
                    visible: h.canSave && !h.loading
                    iconName: h.saved ? "heart" : "heart-outline"
                    tint: h.saved ? Theme.like : Theme.text
                    tip: h.saved ? "Hapus dari Koleksi" : "Simpan ke Koleksi"
                    onClicked: h.saveToggled()
                }
                NButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.canImport && !h.loading
                    text: "Impor ke Koleksi"
                    iconName: "download"
                    onClicked: h.importRequested()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.isLocal && !h.loading
                    iconName: "more"
                    size: 18
                    tip: "Opsi playlist"
                    onClicked: moreMenu.popup()
                    NMenu {
                        id: moreMenu
                        MenuItem { text: "Ganti nama…"; onTriggered: h.renameRequested() }
                        MenuItem { text: "Hapus playlist…"; onTriggered: h.deleteRequested() }
                    }
                }
                BusyIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    running: h.loading
                    visible: running
                    implicitWidth: 32; implicitHeight: 32
                }
            }
        }
    }

    // outlined square icon button next to the play pill
    component SquareButton: AbstractButton {
        id: sq
        property string iconName
        property color tint: Theme.text
        property string tip
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 40
        implicitHeight: 40
        hoverEnabled: true
        focusPolicy: Qt.TabFocus
        opacity: enabled ? 1 : 0.4
        background: Rectangle {
            radius: 10
            color: sq.down ? Theme.pressed : sq.hovered ? Theme.hover : "transparent"
            border.color: sq.hovered || sq.visualFocus ? Theme.lineStrong : Theme.line
        }
        contentItem: Item {
            Icon { anchors.centerIn: parent; glyph: sq.iconName; size: 18; color: sq.tint }
        }
        ToolTip.visible: tip !== "" && hovered
        ToolTip.text: tip
        ToolTip.delay: 600
    }
}
