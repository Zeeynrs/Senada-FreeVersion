import QtQuick
import QtQuick.Controls

// The queue as a mixtape's handwritten track list on a paper card: the playing song on top
// with a highlighter, then the songs to come; click one to play it. Used by the cassette and
// Walkman full views.
PaperCard {
    id: listCard
    readonly property var s: player ? player.state : ({})
    handFont: Theme.handFont
    title: I18n.t("Up next") + " — " + I18n.t("Side B")

    ListView {
        id: tracks
        anchors.fill: parent
        anchors.bottomMargin: 8
        clip: true
        model: player.queue
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}
        SmoothScroll { flickable: tracks }
        Component.onCompleted: player.refreshQueue()

        // the song playing now heads the list, marked like the sung lyric line
        header: Item {
            width: tracks.width
            height: listCard.s.hasTrack ? 52 : 0
            visible: listCard.s.hasTrack
            Rectangle {
                x: listCard.textX - 4
                y: 10
                width: Math.min(nowText.contentWidth + 8, parent.width - x - 8)
                height: 30
                radius: 3
                color: Qt.rgba(1, 0.86, 0.3, 0.75)
            }
            Label {
                id: nowText
                x: listCard.textX
                y: 12
                width: parent.width - listCard.textX - 70
                text: "♪  " + (listCard.s.name || "") + (listCard.s.artists ? " — " + listCard.s.artists : "")
                font.family: Theme.handFont
                font.pixelSize: 20
                font.weight: Font.Bold
                color: listCard.ink
                elide: Text.ElideRight
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 18
                y: 14
                text: Theme.fmt(listCard.s.durationMs || 0)
                font.family: Theme.handFont
                font.pixelSize: 17
                color: Qt.rgba(0.15, 0.15, 0.19, 0.6)
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.35, 0.5, 0.8, 0.22) }
        }

        delegate: Item {
            id: trackRow
            required property var modelData
            required property int index
            width: tracks.width
            height: 46
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: 1
                color: Qt.rgba(0.35, 0.5, 0.8, trackHover.hovered ? 0.08 : 0)
            }
            Label {
                x: 6
                width: listCard.textX - 22   // ends left of the margin line
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: (trackRow.index + 1) + "."
                font.family: Theme.handFont
                font.pixelSize: 16
                color: Qt.rgba(0.85, 0.3, 0.3, 0.75)
            }
            Label {
                x: listCard.textX
                width: parent.width - listCard.textX - 70
                anchors.verticalCenter: parent.verticalCenter
                text: (trackRow.modelData.name || "") + (trackRow.modelData.artists ? " — " + trackRow.modelData.artists : "")
                font.family: Theme.handFont
                font.pixelSize: 18
                color: listCard.ink
                opacity: 0.85
                elide: Text.ElideRight
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: trackRow.modelData.durationMs ? Theme.fmt(trackRow.modelData.durationMs) : ""
                font.family: Theme.handFont
                font.pixelSize: 16
                color: Qt.rgba(0.15, 0.15, 0.19, 0.55)
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.35, 0.5, 0.8, 0.22) }
            HoverHandler { id: trackHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: player.skip(trackRow.index + 1) }
            ToolTip.visible: trackHover.hovered
            ToolTip.delay: 600
            ToolTip.text: I18n.t("Play")
        }

        Label {
            anchors.centerIn: parent
            visible: tracks.count === 0
            text: I18n.t("The queue is empty")
            font.family: Theme.handFont
            font.pixelSize: 18
            color: Qt.rgba(0.15, 0.15, 0.19, 0.55)
        }
    }
}
