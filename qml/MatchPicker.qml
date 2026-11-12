import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Pilih versi lain…": every YouTube Music upload that could be this (imported) track,
// with its match score, so a wrong pick can be corrected by hand.
Popup {
    id: picker
    property var track: ({})
    property var candidates: []
    property bool loading: false

    function openFor(t) {
        track = t
        candidates = []
        loading = true
        open()
        library.matchCandidates(t)
    }

    function typeLabel(t) {
        if (t === "MUSIC_VIDEO_TYPE_ATV") return "Lagu resmi"
        if (t === "MUSIC_VIDEO_TYPE_OMV") return "Video musik"
        if (t === "MUSIC_VIDEO_TYPE_UGC") return "Unggahan pengguna"
        return "Video"
    }
    function scoreColor(s) {
        return s >= library.matchThreshold ? Theme.ok : s >= 45 ? Theme.warn : Theme.danger
    }

    Connections {
        target: library
        function onMatchCandidatesReady(uri, list) {
            if (uri !== (picker.track.uri || "")) return
            picker.candidates = list
            picker.loading = false
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(680, parent ? parent.width - 48 : 680)
    height: Math.min(600, parent ? parent.height - 80 : 600)
    modal: true
    focus: true
    padding: 24
    background: Rectangle { radius: 16; color: Theme.surface2; border.color: Theme.line }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Pilih versi yang benar"; font.pixelSize: 20; font.weight: Font.Bold }
                Label {
                    Layout.fillWidth: true
                    text: (picker.track.name || "") + " — " + (picker.track.artists || "")
                          + (picker.track.durationMs ? "  (" + Theme.fmt(picker.track.durationMs) + ")" : "")
                    color: Theme.dim
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
            IconButton { iconName: "close"; size: 18; tip: "Tutup"; onClicked: picker.close() }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.faint
            font.pixelSize: 12
            text: "Skor menggabungkan kemiripan judul, artis, durasi, dan jenis unggahan. Versi live, cover, karaoke, atau remix diberi skor rendah kecuali memang yang dicari."
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            BusyIndicator { anchors.centerIn: parent; running: picker.loading; visible: running }
            Label {
                anchors.centerIn: parent
                visible: !picker.loading && picker.candidates.length === 0
                text: "Tidak ada kandidat. Periksa koneksi internet."
                color: Theme.dim
            }

            ListView {
                id: list
                SmoothScroll { flickable: list }
                anchors.fill: parent
                clip: true
                spacing: 4
                model: picker.candidates
                ScrollBar.vertical: NScrollBar {}
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 68
                    radius: 10
                    color: modelData.current ? Theme.hover : rowHover.hovered ? Theme.subtle : "transparent"
                    border.width: modelData.current ? 1 : 0
                    border.color: Theme.lineStrong
                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Cover {
                            Layout.preferredWidth: 48; Layout.preferredHeight: 48
                            radius: 12
                            simple: true
                            source: row.modelData.imageSmall || ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                Layout.fillWidth: true
                                text: row.modelData.name || ""
                                elide: Text.ElideRight
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: Theme.dim
                                font.pixelSize: 12
                                text: (row.modelData.artists || "") + "  •  " + picker.typeLabel(row.modelData.videoType)
                                      + (row.modelData.durationMs ? "  •  " + Theme.fmt(row.modelData.durationMs)
                                         + (row.modelData.deltaMs !== null && row.modelData.deltaMs !== undefined && Math.abs(row.modelData.deltaMs) >= 1000
                                            ? " (" + (row.modelData.deltaMs > 0 ? "+" : "−") + Math.round(Math.abs(row.modelData.deltaMs) / 1000) + " dtk)" : "")
                                         : "")
                                      + ((row.modelData.tags || []).length ? "  •  " + row.modelData.tags.join(", ") : "")
                            }
                        }
                        // score pill
                        Rectangle {
                            implicitWidth: 46; implicitHeight: 26; radius: 13
                            color: Theme.alpha(picker.scoreColor(row.modelData.score), 0.16)
                            border.color: Theme.alpha(picker.scoreColor(row.modelData.score), 0.5)
                            Label {
                                anchors.centerIn: parent
                                text: row.modelData.score
                                color: picker.scoreColor(row.modelData.score)
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }
                        IconButton {
                            iconName: "play"; size: 16; tint: Theme.dim
                            tip: "Coba dengarkan versi ini"
                            onClicked: player.playUris(["yt:track:" + row.modelData.id], 0)
                        }
                        NButton {
                            text: row.modelData.current ? "Dipakai" : "Pakai"
                            primary: !row.modelData.current
                            enabled: !row.modelData.current
                            onClicked: {
                                library.chooseMatch(picker.track, row.modelData)
                                picker.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
