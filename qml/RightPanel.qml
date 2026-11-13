import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Right panel next to the page: synced lyrics or the play queue.
Rectangle {
    id: rp
    property string panel: "lyrics"   // "lyrics" | "queue"
    signal select(string name)
    signal close()
    readonly property var s: player.state

    color: Theme.sidebar
    clip: true

    Rectangle { width: 1; height: parent.height; color: Theme.line }

    // header: two tabs and a close button
    RowLayout {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        height: 46
        spacing: 16
        Repeater {
            model: [{ key: "lyrics", label: I18n.t("LYRICS") }, { key: "queue", label: I18n.t("QUEUE") }]
            Label {
                required property var modelData
                text: modelData.label
                color: rp.panel === modelData.key ? Theme.text : tabHover.hovered ? Theme.dim : Theme.faint
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: rp.select(modelData.key) }
            }
        }
        Item { Layout.fillWidth: true }
        IconButton { iconName: "close"; size: 16; tint: Theme.dim; tip: I18n.t("Close panel"); onClicked: rp.close() }
    }
    Rectangle { anchors.top: head.bottom; x: 1; width: parent.width - 1; height: 1; color: Theme.line }

    Loader {
        anchors.top: head.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: rp.panel === "queue" ? queueComp : lyricsComp
    }

    // ---- lyrics -----------------------------------------------------------------------
    Component {
        id: lyricsComp
        Item {
            Label {
                anchors.centerIn: lines
                width: parent.width - 48
                visible: lyrics.status !== "ready"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.dim
                font.pixelSize: 14
                text: lyrics.status === "loading" ? I18n.t("Looking for lyrics…")
                    : lyrics.status === "idle" ? I18n.t("Play a song to see its lyrics.")
                    : lyrics.status === "error" ? I18n.t("Lyrics could not be loaded. Check the internet connection.")
                    : lyrics.source === "auto" ? I18n.t("No lyrics for this song yet.")
                    : I18n.t("No lyrics for this song from this source. Try another source below.")
            }
            ListView {
                id: lines
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: sourceBar.top
                visible: lyrics.status === "ready"
                clip: true
                model: lyrics.lines
                spacing: 6
                topMargin: height * 0.3
                bottomMargin: height * 0.5
                currentIndex: lyrics.synced ? lyrics.current : -1
                // keep the sung line in view, unless the user is scrolling by hand
                highlightRangeMode: lyrics.synced && !userScroll.running ? ListView.ApplyRange : ListView.NoHighlightRange
                preferredHighlightBegin: height * 0.3
                preferredHighlightEnd: height * 0.3 + 60
                highlightMoveDuration: 380
                ScrollBar.vertical: NScrollBar {}
                SmoothScroll { flickable: lines }
                onMovementStarted: userScroll.restart()
                Timer { id: userScroll; interval: 3500 }
                onModelChanged: positionViewAtBeginning()

                delegate: Label {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: lyrics.synced && index === lyrics.current
                    width: lines.width
                    leftPadding: 18
                    rightPadding: 18
                    topPadding: 4
                    bottomPadding: 4
                    text: modelData.text || "♪"
                    wrapMode: Text.WordWrap
                    font.pixelSize: lyrics.synced ? 20 : 16
                    font.weight: lyrics.synced ? Font.Bold : Font.Normal
                    color: !lyrics.synced ? Theme.text
                         : isCurrent ? Theme.accentInk
                         : lineHover.hovered ? Theme.dim : Theme.alpha(Theme.text, index < lyrics.current ? 0.32 : 0.42)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    HoverHandler { id: lineHover; cursorShape: lyrics.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (lyrics.synced) player.seek(line.modelData.t) }
                }
            }
            // which source the lyrics come from, and a menu to pick another one
            Item {
                id: sourceBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: lyrics.status === "idle" ? 0 : 38
                visible: height > 0
                Rectangle { width: parent.width; height: 1; color: Theme.line }
                LyricsSourceButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ---- queue -------------------------------------------------------------------------
    Component {
        id: queueComp
        ListView {
            id: q
            clip: true
            model: player.queue
            spacing: 0
            ScrollBar.vertical: NScrollBar {}
            SmoothScroll { flickable: q }
            Component.onCompleted: player.refreshQueue()
            bottomMargin: 16

            header: Column {
                width: q.width
                topPadding: 12
                spacing: 4
                SectionLabel { text: I18n.t("NOW PLAYING") }
                Label {
                    visible: !rp.s.hasTrack
                    leftPadding: 16
                    text: I18n.t("Nothing playing yet.")
                    color: Theme.dim
                    font.pixelSize: 13
                }
                TrackRow {
                    visible: !!rp.s.hasTrack
                    width: q.width
                    track: rp.s.hasTrack ? rp.s : ({})
                    compact: true
                    onPlay: player.togglePlay()
                }
                Item { width: 1; height: 10 }
                SectionLabel { text: I18n.t("UP NEXT"); visible: q.count > 0 }
                Label {
                    visible: q.count === 0
                    leftPadding: 16
                    text: I18n.t("The queue is empty. Play an album or playlist, or choose “Add to queue” on any song.")
                    width: q.width - 16
                    wrapMode: Text.WordWrap
                    color: Theme.dim
                    font.pixelSize: 13
                }
            }
            delegate: TrackRow {
                required property var modelData
                required property int index
                width: q.width
                track: modelData
                compact: true
                onPlay: player.skip(index + 1)
            }
        }
    }

    component SectionLabel: Label {
        leftPadding: 16
        bottomPadding: 4
        color: Theme.faint
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 1.2
    }
}
