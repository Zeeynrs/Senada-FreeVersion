import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Big cover + title block used by playlist, album, liked and artist pages.
// The cover sits on a blurred glow of itself; artists get the bloom (scalloped) shape.
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
    signal playAll()
    signal shuffleAll()
    signal saveToggled()
    signal importRequested()
    signal renameRequested()
    signal deleteRequested()

    readonly property url art: h.info.imageLarge || h.info.image || ""
    readonly property real coverSide: Math.min(232, Math.max(150, h.width * 0.22))

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

            // glow: the cover itself, blurred, behind the cover
            Image {
                id: glowSrc
                anchors.fill: parent
                source: h.art
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                anchors.margins: -18
                anchors.topMargin: 6
                source: glowSrc
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                saturation: 0.4
                opacity: glowSrc.status === Image.Ready ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: 500 } }
            }
            Cover {
                anchors.fill: parent
                radius: 28
                scalloped: h.round
                scallops: 18
                scallopDepth: 0.04
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

            // type label as a mint outline pill
            Rectangle {
                visible: typeText.text !== ""
                implicitWidth: typeText.implicitWidth + 22
                implicitHeight: 26
                radius: 13
                color: Theme.alpha(Theme.mint, 0.1)
                border.color: Theme.alpha(Theme.mint, 0.45)
                Label {
                    id: typeText
                    anchors.centerIn: parent
                    text: h.info.typeLabel || (h.round ? "Artis" : "")
                    color: Theme.mint
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 0.4
                }
            }
            Label {
                Layout.fillWidth: true
                text: h.loading && !h.info.name ? "Memuat…" : (h.info.name || "")
                font.pixelSize: Math.max(32, Math.min(64, h.width / 15))
                font.weight: Font.Black
                font.letterSpacing: -1
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
                font.pixelSize: 14
                color: Theme.text
            }

            Row {
                Layout.topMargin: 12
                spacing: 12
                BloomPlayButton {
                    size: 60
                    tip: "Putar"
                    enabled: !h.loading && (!!h.info.playUri || (h.info.tracks && h.info.tracks.length > 0))
                    onClicked: h.playAll()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "shuffle"
                    size: 24
                    tint: Theme.dim
                    tip: "Putar acak"
                    enabled: !h.loading
                    onClicked: h.shuffleAll()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.canSave && !h.loading
                    iconName: h.saved ? "heart" : "heart-outline"
                    size: 24
                    tint: h.saved ? Theme.fuchsia : Theme.dim
                    tip: h.saved ? "Hapus dari Library" : "Simpan ke Library"
                    onClicked: h.saveToggled()
                }
                NButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.canImport && !h.loading
                    text: "Impor ke Library"
                    iconName: "download"
                    onClicked: h.importRequested()
                }
                NButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.isLocal && !h.loading
                    text: "Ganti nama"
                    onClicked: h.renameRequested()
                }
                NButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: h.isLocal && !h.loading
                    text: "Hapus"
                    onClicked: h.deleteRequested()
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
}
