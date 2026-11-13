import QtQuick
import QtQuick.Controls

Item {
    id: lv
    property int textSize: 26     // synced lines; plain lyrics are a little smaller
    property int lineGap: 22
    property bool followHeight: false   // keep the sung line in place while the view grows/shrinks

    // jump to the sung line, e.g. after the view was hidden or resized (the list only moves
    // by itself when the line changes)
    function settle() {
        if (list.currentIndex < 0 || list.height <= 0)
            return
        list.positionViewAtIndex(list.currentIndex, ListView.Beginning)
        list.contentY = Math.max(list.originY, list.contentY - list.preferredHighlightBegin)
    }

    ListView {
        id: list
        SmoothScroll { flickable: list }
        anchors.fill: parent
        clip: true
        model: lyrics.lines
        spacing: lv.lineGap
        currentIndex: lyrics.synced ? lyrics.current : -1
        highlightRangeMode: lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.34
        preferredHighlightEnd: height * 0.34 + 84
        highlightMoveDuration: 550
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        onHeightChanged: if (lv.followHeight) lv.settle()
        header: Item { width: 1; height: list.height * 0.26 }
        footer: Item { width: 1; height: list.height * 0.48 }
        ScrollBar.vertical: NScrollBar {}

        delegate: Item {
            id: row
            readonly property bool isCurrent: lyrics.synced && index === lyrics.current
            readonly property bool past: lyrics.synced && index < lyrics.current
            width: list.width - 20
            height: lineLabel.implicitHeight + lv.lineGap + 2

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
                font.pixelSize: lyrics.synced ? lv.textSize : Math.round(lv.textSize * 0.85)
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
            text: ({ "loading": I18n.t("Loading lyrics…"), "none": I18n.t("No lyrics found for this song"),
                     "error": I18n.t("Could not load lyrics"), "idle": I18n.t("Play a song to see its lyrics") })[lyrics.status] || ""
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: Math.round(lv.textSize * 0.7)
        }
    }
}
