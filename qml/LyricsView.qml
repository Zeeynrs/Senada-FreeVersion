import QtQuick
import QtQuick.Controls

Item {
    id: lv

    ListView {
        id: list
        SmoothScroll { flickable: list }
        anchors.fill: parent
        clip: true
        model: lyrics.lines
        spacing: 22
        currentIndex: lyrics.synced ? lyrics.current : -1
        highlightRangeMode: lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.34
        preferredHighlightEnd: height * 0.34 + 84
        highlightMoveDuration: 550
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        header: Item { width: 1; height: list.height * 0.26 }
        footer: Item { width: 1; height: list.height * 0.48 }
        ScrollBar.vertical: NScrollBar {}

        delegate: Item {
            id: row
            readonly property bool isCurrent: lyrics.synced && index === lyrics.current
            readonly property bool past: lyrics.synced && index < lyrics.current
            width: list.width - 20
            height: lineLabel.implicitHeight + 24

            Label {
                id: lineLabel
                x: 10
                transformOrigin: Item.Left
                scale: row.isCurrent ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 34
                text: modelData.text || "♪"
                wrapMode: Text.WordWrap
                font.pixelSize: lyrics.synced ? 26 : 22
                font.weight: Font.Bold
                color: !lyrics.synced ? Qt.rgba(1, 1, 1, 0.85)
                     : row.isCurrent ? "#ffffff"
                     : row.past ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.36)
                Behavior on color { ColorAnimation { duration: 280 } }
            }

            HoverHandler { cursorShape: lyrics.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (lyrics.synced) player.seek(modelData.t) }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: lyrics.status !== "ready"
        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: lyrics.status === "loading"; visible: running }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({ "loading": "Memuat lirik…", "none": "Lirik tidak ditemukan untuk lagu ini",
                     "error": "Gagal memuat lirik", "idle": "Putar lagu untuk melihat lirik" })[lyrics.status] || ""
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 18
        }
    }
}
