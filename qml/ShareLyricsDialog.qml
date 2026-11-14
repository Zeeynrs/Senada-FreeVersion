import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

// "Share lyrics": pick a few lines of the song that is playing and turn them into a picture
// (1080 × 1350, fits a feed post and a story) with the cover, the title and the artist,
// to copy or save in Pictures/Senada. Opened with Nav.shareLyrics from the lyric views.
Popup {
    id: dlg
    property var picked: []          // indexes into lyrics.lines, in order
    property string look: "cover"    // background of the card: "cover", "color", "dark"
    property string savedPath: ""
    readonly property var lines: lyrics.status === "ready" ? lyrics.lines : []
    readonly property string cardText: picked.map(i => (lines[i] && lines[i].text) || "").join("\n")
    readonly property color tint: Theme.songHasColor ? Theme.accent : "#5b5f66"
    readonly property string cover: player.state.imageLarge || player.state.image || ""

    // start at `index` (-1: the line being sung) with that line and the two after it
    function openAt(index) {
        const n = lines.length
        let start = index >= 0 ? index : lyrics.synced ? Math.max(0, lyrics.current) : 0
        const chosen = []
        for (let i = start; i < Math.min(n, start + 3); i++)
            if ((lines[i].text || "").trim())
                chosen.push(i)
        picked = chosen
        savedPath = ""
        open()
        list.positionViewAtIndex(Math.max(0, start), ListView.Center)
    }
    function toggle(i) {
        const set = picked.slice()
        const at = set.indexOf(i)
        if (at >= 0) set.splice(at, 1)
        else if (set.length < 8) set.push(i)
        picked = set.sort((a, b) => a - b)
    }
    function fileName() {
        return (player.state.artists || "Senada") + " - " + (player.state.name || I18n.t("Lyrics"))
    }
    function grab(then) {
        card.grabToImage(result => then(result), Qt.size(card.width, card.height))
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(940, parent ? parent.width - 48 : 940)
    height: Math.min(680, parent ? parent.height - 64 : 680)
    modal: true
    focus: true
    padding: 24
    background: Rectangle { radius: 16; color: Theme.surface2; border.color: Theme.line }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    contentItem: RowLayout {
        spacing: 24

        // ---- the card, shown scaled down; it is grabbed at full size -------------------------
        Item {
            id: previewBox
            Layout.fillHeight: true
            Layout.preferredWidth: height * card.width / card.height
            Item {
                anchors.centerIn: parent
                width: card.width * scale
                height: card.height * scale
                scale: previewBox.height / card.height
                transformOrigin: Item.TopLeft

                Item {
                    id: card
                    width: 1080
                    height: 1350
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: dlg.look === "dark" ? "#17181b" : Qt.darker(dlg.tint, 1.5) }
                            GradientStop { position: 1; color: dlg.look === "dark" ? "#050506" : Qt.darker(dlg.tint, 3.2) }
                        }
                    }
                    Image {
                        id: bgCover
                        anchors.fill: parent
                        anchors.margins: -120
                        visible: dlg.look === "cover" && status === Image.Ready
                        source: dlg.cover
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(640, 640)
                        layer.enabled: visible
                        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.15 }
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: bgCover.visible
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.30) }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.62) }
                        }
                    }

                    // cover, title and artist
                    RowLayout {
                        id: head
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 88 }
                        spacing: 32
                        Cover {
                            Layout.preferredWidth: 168
                            Layout.preferredHeight: 168
                            source: dlg.cover
                            radius: 18
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                Layout.fillWidth: true
                                text: player.state.name || ""
                                color: "#ffffff"
                                font.pixelSize: 46
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: player.state.artists || ""
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: 34
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // the lines: as big as they fit
                    Text {
                        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top
                                  leftMargin: 88; rightMargin: 88; topMargin: 72; bottomMargin: 56 }
                        text: dlg.cardText || "♪"
                        color: "#ffffff"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Theme.lyricsCentered ? Text.AlignHCenter : Text.AlignLeft
                        font.family: Theme.lyricsSerif ? "Georgia" : Qt.application.font.family
                        font.weight: Font.Bold
                        font.pixelSize: 80
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 30
                        lineHeight: 1.12
                    }

                    // the Senada mark at the bottom
                    Row {
                        id: foot
                        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 88; bottomMargin: 80 }
                        spacing: 16
                        LogoMark { size: 44; colors: ["#ffffff"]; anchors.verticalCenter: parent.verticalCenter }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Senada"
                            color: "#ffffff"
                            opacity: 0.9
                            font.pixelSize: 34
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // ---- choosing ------------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: I18n.t("Share lyrics")
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                IconButton { iconName: "close"; size: 18; tip: I18n.t("Close"); onClicked: dlg.close() }
            }
            Label {
                Layout.fillWidth: true
                text: I18n.t("Pick up to 8 lines for the picture.")
                color: Theme.dim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: dlg.lines
                spacing: 2
                ScrollBar.vertical: NScrollBar {}
                delegate: ItemDelegate {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool chosen: dlg.picked.indexOf(index) >= 0
                    readonly property bool empty: !(modelData.text || "").trim()
                    width: list.width - 12
                    enabled: !empty
                    visible: !empty
                    height: empty ? 0 : implicitHeight
                    padding: 10
                    background: Rectangle {
                        radius: 8
                        color: row.chosen ? Theme.alpha(Theme.primary, 0.18) : row.hovered ? Theme.hover : "transparent"
                    }
                    contentItem: Label {
                        text: row.modelData.text || ""
                        wrapMode: Text.WordWrap
                        color: row.chosen ? Theme.text : Theme.dim
                        font.pixelSize: 14
                        font.weight: row.chosen ? Font.DemiBold : Font.Normal
                    }
                    onClicked: dlg.toggle(index)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: I18n.t("Background"); color: Theme.dim; font.pixelSize: 13 }
                Repeater {
                    model: [{ key: "cover", label: I18n.t("Cover") }, { key: "color", label: I18n.t("Song color") },
                            { key: "dark", label: I18n.t("Dark") }]
                    delegate: Chip {
                        required property var modelData
                        text: modelData.label
                        checked: dlg.look === modelData.key
                        onClicked: dlg.look = modelData.key
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                NButton {
                    text: I18n.t("Copy image")
                    enabled: dlg.picked.length > 0
                    onClicked: dlg.grab(r => session.copyImage(r.image))
                }
                NButton {
                    primary: true
                    text: I18n.t("Save image")
                    enabled: dlg.picked.length > 0
                    onClicked: {
                        const path = session.picturePath(dlg.fileName())
                        dlg.grab(r => {
                            if (r.saveToFile(path)) {
                                dlg.savedPath = path
                                session.toast(I18n.t("Saved in Pictures/Senada"))
                            } else {
                                session.toast(I18n.t("The picture could not be saved"))
                            }
                        })
                    }
                }
                LinkLabel {
                    visible: dlg.savedPath !== ""
                    text: I18n.t("Show in folder")
                    onClicked: session.showFile(dlg.savedPath)
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
