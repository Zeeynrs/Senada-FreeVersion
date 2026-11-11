import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "home"
    readonly property var home: library.home
    readonly property var sections: home.sections || []

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 20
            y: 52
            width: flick.width - 40
            spacing: 28

            RowLayout {
                width: parent.width
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    text: Theme.greeting() + (library.me.name ? ", " + library.me.name.split(" ")[0] : "")
                    font.pixelSize: 36
                    font.weight: Font.Black
                    elide: Text.ElideRight
                }
                IconButton { iconName: "refresh"; tip: "Muat ulang"; onClicked: library.refreshAll() }
            }

            // quick tiles: liked songs and the first library entries
            GridLayout {
                width: parent.width
                columns: width > 900 ? 4 : 2
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: [{ kind: "liked", id: "", name: "Lagu yang Disukai", imageSmall: "" }].concat(library.playlists.slice(0, 7))
                    AbstractButton {
                        id: tile
                        Layout.fillWidth: true
                        implicitHeight: 64
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        onClicked: Nav.go(modelData.kind, modelData.id)
                        background: Rectangle {
                            radius: 14
                            color: tile.hovered ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.06)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            Cover {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                radius: 14
                                round: modelData.kind === "artist"
                                source: modelData.imageSmall || ""
                                fallbackIcon: modelData.kind === "liked" ? "heart" : modelData.kind === "artist" ? "speaker" : "note"
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            TrackSection {
                width: parent.width
                title: "Baru saja diputar"
                tracks: library.recent
            }

            // loading / error state for the YouTube Music shelves
            Column {
                width: parent.width
                visible: page.sections.length === 0
                spacing: 12
                RowLayout {
                    x: 12
                    spacing: 12
                    BusyIndicator {
                        running: !!page.home.loading
                        visible: running
                        implicitWidth: 32; implicitHeight: 32
                    }
                    Label {
                        text: page.home.loading ? "Memuat musik dari YouTube Music…" : (page.home.error || "")
                        color: page.home.loading ? Theme.dim : Theme.danger
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                }
                NButton {
                    x: 12
                    visible: !page.home.loading && !!page.home.error
                    text: "Coba lagi"
                    iconName: "refresh"
                    onClicked: library.refreshAll()
                }
            }

            Repeater {
                model: page.sections
                Column {
                    width: col.width
                    spacing: 16
                    TrackSection {
                        width: parent.width
                        title: modelData.title
                        tracks: modelData.tracks || []
                    }
                    CardGrid {
                        width: parent.width
                        title: (modelData.tracks || []).length > 0 ? "" : modelData.title
                        items: modelData.cards || []
                        rows: 1
                    }
                }
            }
        }
    }

    // a titled list of tracks that shows five rows and expands on demand
    component TrackSection: Column {
        id: ts
        property string title
        property var tracks: []
        property bool expanded: false
        visible: tracks.length > 0
        spacing: 2

        Item {
            width: parent.width
            height: 40
            Label {
                text: ts.title
                font.pixelSize: 22
                font.weight: Font.Bold
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            LinkLabel {
                visible: ts.tracks.length > 5
                text: ts.expanded ? "Lebih sedikit" : "Tampilkan semua"
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                onClicked: ts.expanded = !ts.expanded
            }
        }
        Repeater {
            model: ts.expanded ? ts.tracks : ts.tracks.slice(0, 5)
            TrackRow {
                width: ts.width
                track: modelData
                number: index + 1
                onPlay: player.playUris(ts.tracks.map(x => x.uri), index)
            }
        }
    }
}
