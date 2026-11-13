import QtQuick
import QtQuick.Controls

// The lyrics written on a ruled paper card, the sung line marked with a highlighter; click a
// line to jump there. Used by the cassette and Walkman full views.
PaperCard {
    id: card
    readonly property real lineGap: 8
    readonly property var s: player ? player.state : ({})
    handFont: Theme.handFont
    title: I18n.t("Lyrics") + (card.s.name ? " — " + card.s.name : "")

    ListView {
        id: lines
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: sourceButton.top
        clip: true
        model: lyrics.status === "ready" ? lyrics.lines : []
        currentIndex: lyrics.synced ? lyrics.current : -1
        highlightRangeMode: lyrics.synced && !handScroll.running ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.3
        preferredHighlightEnd: height * 0.3 + 48
        highlightMoveDuration: 450
        boundsBehavior: Flickable.StopAtBounds
        onMovementStarted: handScroll.restart()
        Timer { id: handScroll; interval: 3500 }
        ScrollBar.vertical: NScrollBar {}
        SmoothScroll { flickable: lines }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool isCurrent: lyrics.synced && index === lyrics.current
            readonly property bool past: lyrics.synced && index < lyrics.current
            width: lines.width
            height: lineText.implicitHeight + card.lineGap * 2

            // highlighter on the sung line
            Rectangle {
                x: lineText.x - 4
                y: lineText.y + 2
                width: Math.min(lineText.contentWidth + 8, row.width - x - 8)
                height: lineText.implicitHeight - 2
                radius: 3
                color: Qt.rgba(1, 0.86, 0.3, 0.75)
                opacity: row.isCurrent ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260 } }
            }
            Label {
                id: lineText
                x: card.textX
                y: card.lineGap
                width: row.width - card.textX - 16
                text: row.modelData.text || "♪"
                wrapMode: Text.WordWrap
                font.family: Theme.handFont
                font.pixelSize: lyrics.synced ? 21 : 18
                font.weight: row.isCurrent ? Font.Bold : Font.Normal
                color: card.ink
                opacity: !lyrics.synced || row.isCurrent ? 1 : row.past ? 0.42 : 0.7
                Behavior on opacity { NumberAnimation { duration: 260 } }
            }
            // ruled line
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.35, 0.5, 0.8, 0.22) }
            HoverHandler { cursorShape: lyrics.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (lyrics.synced) player.seek(row.modelData.t) }
        }
    }

    Column {
        anchors.centerIn: lines
        width: lines.width - 96
        spacing: 8
        visible: lyrics.status !== "ready"
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: ({ "loading": I18n.t("Loading lyrics…"), "none": I18n.t("No lyrics found for this song"),
                     "error": I18n.t("Could not load lyrics"), "idle": I18n.t("Play a song to see its lyrics") })[lyrics.status] || ""
            font.family: Theme.handFont
            font.pixelSize: 18
            color: Qt.rgba(0.15, 0.15, 0.19, 0.6)
        }
        Label {
            visible: lyrics.status === "none" && lyrics.source !== "auto"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("Try another source below.")
            font.pixelSize: 13
            color: Qt.rgba(0.15, 0.15, 0.19, 0.5)
        }
    }

    LyricsSourceButton {
        id: sourceButton
        x: card.textX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        visible: lyrics.status !== "idle"
        height: visible ? implicitHeight : 0
        tint: Qt.rgba(0.15, 0.15, 0.19, 0.55)
        hoverTint: card.ink
    }
}
