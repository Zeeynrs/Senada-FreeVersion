import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Titled tracks in one or two columns (`wide`): a few rows, more on demand, and "Play all".
Column {
    id: ts
    property string title
    property var tracks: []
    property bool wide: false
    property bool expanded: false
    readonly property int cols: wide ? 2 : 1
    readonly property int collapsed: cols * 3
    visible: tracks.length > 0
    spacing: 6

    Item {
        width: parent.width
        height: 40
        Label {
            text: ts.title
            font.pixelSize: 18
            font.weight: Font.Bold
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                text: I18n.t("Play all")
                iconName: "play"
                onClicked: player.playUris(ts.tracks.map(x => x.uri), 0)
            }
            Chip {
                visible: ts.tracks.length > ts.collapsed
                text: ts.expanded ? I18n.t("Show less") : I18n.t("All ({n})", { n: ts.tracks.length })
                onClicked: ts.expanded = !ts.expanded
            }
        }
    }
    GridLayout {
        width: parent.width
        columns: ts.cols
        columnSpacing: 24
        rowSpacing: 0
        Repeater {
            model: ts.expanded ? ts.tracks : ts.tracks.slice(0, ts.collapsed)
            TrackRow {
                Layout.fillWidth: true
                Layout.preferredWidth: ts.width / ts.cols
                track: modelData
                number: index + 1
                showAlbum: ts.cols === 1
                onPlay: player.playUris(ts.tracks.map(x => x.uri), index)
            }
        }
    }
}
