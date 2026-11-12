import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Column titles above table-mode TrackRows; click a title to sort by it
// (ascending, descending, then back to the original order).
Item {
    id: th
    property bool showCover: true
    property bool showAlbum: true
    property string sortKey: ""     // "" | "number" | "name" | "artists" | "album" | "durationMs"
    property bool sortAsc: true
    property real inset: 0
    readonly property bool wide: width - 2 * inset > 560
    signal sortBy(string key)

    implicitHeight: 38

    Rectangle { anchors.bottom: parent.bottom; x: th.inset; width: parent.width - 2 * th.inset; height: 1; color: Theme.line }

    component Head: Item {
        id: h
        property string key
        property string text
        property int align: Qt.AlignLeft
        Layout.fillHeight: true
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: h.align === Qt.AlignRight ? parent.right : undefined
            spacing: 4
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: h.text
                color: th.sortKey === h.key || hh.hovered ? Theme.text : Theme.dim
                font.pixelSize: 12
                font.weight: th.sortKey === h.key ? Font.Bold : Font.Normal
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: th.sortKey === h.key ? (th.sortAsc ? "expand-more" : "expand-more") : "sort"
                rotation: th.sortKey === h.key && th.sortAsc ? 180 : 0
                size: 13
                color: th.sortKey === h.key ? Theme.text : Theme.faint
                opacity: th.sortKey === h.key || hh.hovered ? 1 : 0.6
            }
        }
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: th.sortBy(h.key) }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: th.inset + 12
        anchors.rightMargin: th.inset + 8
        spacing: 12

        Head { Layout.preferredWidth: 26; key: "number"; text: "#" }
        Item { visible: th.showCover; Layout.preferredWidth: 38 }
        Head {
            Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.horizontalStretchFactor: 4; Layout.minimumWidth: 100
            key: "name"; text: "Judul"
        }
        Head {
            visible: th.wide
            Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.horizontalStretchFactor: 3
            key: "artists"; text: "Artis"
        }
        Head {
            visible: th.wide && th.showAlbum && th.width - 2 * th.inset > 760
            Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.horizontalStretchFactor: 3
            key: "album"; text: "Album"
        }
        Head { Layout.preferredWidth: 44; key: "durationMs"; text: "Durasi"; align: Qt.AlignRight }
        Item { Layout.preferredWidth: 64 }
    }
}
