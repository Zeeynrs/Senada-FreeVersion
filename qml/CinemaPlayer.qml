import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a cinema (Settings → Appearance → Full view style): a dark room with a 16:9
// screen whose light spills into it. The cover is the film: a wide 2.39:1 still between black
// bars that the camera pans down over as the song plays, so all of it is seen by the end.
// A new song opens with its title credits over the picture. The lyrics are the subtitles, in
// the bar under the picture (closed panel: no subtitles, the title in the bar); the queue is the
// board of showtimes beside the screen, each song with the time it starts; the equalizer the
// fine lines of the poster view. Controls sit in a strip along the bottom.
Item {
    id: cp
    property bool active: true            // the full view is on screen
    property string panel: "lyrics"       // "lyrics" | "queue" | "equalizer"
    property bool showPanel: true
    signal closeRequested()
    readonly property var s: player ? player.state : ({})
    readonly property bool playing: !!s.isPlaying
    readonly property real progress: s.durationMs > 0 ? Math.min(1, player.position / s.durationMs) : 0

    readonly property real topSpace: 68
    readonly property real bottomSpace: 116
    readonly property real areaH: height - topSpace - bottomSpace
    readonly property bool side: showPanel && panel !== "lyrics"   // the board or the equalizer beside the screen
    readonly property bool subtitles: showPanel && panel === "lyrics"
    readonly property color accent: Qt.lighter(Theme.accent, 1.2)
    readonly property string serif: "Georgia"

    // the dark room; the blurred art behind shows through faintly, like light in the room
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.015, 0.015, 0.02, 0.9)
    }

    // ---- the screen ------------------------------------------------------------------------------
    readonly property real availW: (side ? width * 0.6 : width) - 2 * 48
    readonly property real screenW: Math.max(320, Math.min(availW, (areaH - 24) * 16 / 9))
    Item {
        id: screen
        x: cp.side ? 48 : (cp.width - width) / 2
        y: cp.topSpace + (cp.areaH - height) / 2
        width: cp.screenW
        height: width * 9 / 16
        Behavior on x { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }

        // the light of the picture falling on the walls and the floor around the screen
        MultiEffect {
            x: -width * 0.12
            y: -height * 0.1
            width: parent.width * 1.24
            height: parent.height * 1.35
            source: film
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            opacity: cp.playing ? 0.5 : 0.25
            Behavior on opacity { NumberAnimation { duration: 900 } }
        }

        Rectangle {  // the screen itself, black where the film has no picture
            anchors.fill: parent
            color: "#020203"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
        }

        // the picture: 2.39:1 between the bars
        Item {
            id: picture
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.round(width / 2.39)
            clip: true

            Item {
                id: film
                anchors.fill: parent
                Image {
                    id: still
                    // a little wider than the picture, so it can drift sideways too
                    width: picture.width * 1.06
                    height: width   // the cover is square: much taller than the picture
                    x: -picture.width * 0.03 + drift.offset
                    // the camera pans from the top of the cover to the bottom as the song plays
                    y: -(height - picture.height) * (0.08 + 0.84 * cp.progress)
                    Behavior on y { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
                    source: cp.s.imageLarge || cp.s.image || ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(1200, 1200)
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 700 } }
                }
                // a slow sideways drift while the film runs
                QtObject {
                    id: drift
                    property real offset: 0
                }
                SequentialAnimation {
                    running: cp.active && cp.playing
                    loops: Animation.Infinite
                    NumberAnimation { target: drift; property: "offset"; to: picture.width * 0.03; duration: 24000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: drift; property: "offset"; to: -picture.width * 0.03; duration: 24000; easing.type: Easing.InOutSine }
                }
            }
            // darker edges, like a lens; darker still while paused
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 0.18; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: cp.playing ? 0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 500 } }
            }

            // opening credits: the title and the artist over the picture when a song starts
            Column {
                id: credits
                anchors.centerIn: parent
                width: parent.width * 0.8
                spacing: Math.round(picture.height * 0.035)
                opacity: 0
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.t("SENADA PRESENTS")
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: Math.max(10, Math.round(picture.height * 0.032))
                    font.letterSpacing: Math.max(3, picture.height * 0.012)
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: (cp.s.name || "").toUpperCase()
                    color: "#ffffff"
                    font.family: cp.serif
                    font.pixelSize: Math.max(22, Math.round(picture.height * 0.11))
                    font.letterSpacing: Math.max(2, picture.height * 0.012)
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cp.s.artists || ""
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.family: cp.serif
                    font.italic: true
                    font.pixelSize: Math.max(13, Math.round(picture.height * 0.045))
                    elide: Text.ElideRight
                }
            }
            SequentialAnimation {
                id: titles
                PauseAnimation { duration: 500 }
                NumberAnimation { target: credits; property: "opacity"; to: 1; duration: 1100; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 3600 }
                NumberAnimation { target: credits; property: "opacity"; to: 0; duration: 1400; easing.type: Easing.InOutQuad }
            }
            Connections {
                target: player
                function onTrackChanged() { cp.rollTitles() }
            }

            HoverHandler { cursorShape: cp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (cp.s.hasTrack) player.togglePlay() }
        }

        // the bar under the picture: the subtitles, or the title of the film
        Item {
            id: lowerBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: picture.bottom
            anchors.bottom: parent.bottom

            readonly property var lines: lyrics.status === "ready" ? lyrics.lines : []
            readonly property int at: lyrics.synced ? lyrics.current : -1
            readonly property string sub: !lyrics.synced ? "" : at >= 0 && at < lines.length ? (lines[at].text || "♪") : ""
            // what stands in for subtitles that cannot be shown
            readonly property string note: ({
                "loading": I18n.t("[ subtitles loading ]"),
                "none": I18n.t("[ no subtitles for this song ]"),
                "error": I18n.t("[ subtitles could not be loaded ]")
            })[lyrics.status] || (lyrics.status === "ready" && !lyrics.synced ? I18n.t("[ the lyrics of this song are not timed ]") : "")

            Label {
                id: subtitle
                anchors.centerIn: parent
                width: parent.width * 0.86
                visible: cp.subtitles
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: lowerBar.sub || lowerBar.note
                color: lowerBar.sub ? "#ffffff" : Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: Math.max(15, Math.min(34, Math.round(cp.screenW * 0.024)))
                font.weight: lowerBar.sub ? Font.DemiBold : Font.Normal
                font.italic: !lowerBar.sub
                style: Text.Outline
                styleColor: "#000000"
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                // films cut from one line to the next; a very short fade keeps it soft
                onTextChanged: { opacity = 0; cut.restart() }
                NumberAnimation { id: cut; target: subtitle; property: "opacity"; to: 1; duration: 140 }
            }
            Label {
                anchors.centerIn: parent
                width: parent.width * 0.86
                visible: !cp.subtitles && !!cp.s.hasTrack
                horizontalAlignment: Text.AlignHCenter
                text: ((cp.s.name || "") + (cp.s.artists ? "   —   " + cp.s.artists : "")).toUpperCase()
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: Math.max(11, Math.round(cp.screenW * 0.012))
                font.letterSpacing: Math.max(2, cp.screenW * 0.003)
                elide: Text.ElideRight
            }
            LyricsSourceButton {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                visible: cp.subtitles && lyrics.status !== "idle" && lowerBar.height > 52
                tint: Qt.rgba(1, 1, 1, 0.35)
                hoverTint: "#ffffff"
            }
        }
        // the top bar: what is showing, and how far
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: picture.top
            anchors.bottomMargin: Math.max(6, (picture.y - height) / 2)
            text: (cp.playing ? "● " + I18n.t("NOW SHOWING") : "❚❚ " + I18n.t("PAUSED"))
            color: cp.playing ? cp.accent : Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 2.4
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: picture.top
            anchors.bottomMargin: Math.max(6, (picture.y - height) / 2)
            visible: !!cp.s.hasTrack
            text: Theme.fmt(player.position) + " / " + Theme.fmt(cp.s.durationMs || 0)
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }

    function rollTitles() {
        credits.opacity = 0
        titles.restart()
    }
    onActiveChanged: if (active) rollTitles()
    Component.onCompleted: rollTitles()

    // ---- beside the screen: the showtimes or the equalizer -------------------------------------------
    Item {
        id: sidePanel
        x: screen.x + screen.width + 44
        y: cp.topSpace + 8
        width: cp.width - x - 48
        height: cp.areaH - 16
        visible: cp.side
        opacity: cp.side ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // the queue as the board of showtimes --------------------------------------------------
        Item {
            id: showtimes
            anchors.fill: parent
            visible: cp.panel === "queue"
            // when each song starts: what is left of this one, then the songs before it, at the tempo
            readonly property real tempo: effects ? Math.max(0.1, effects.tempo) : 1
            // the clock, read again whenever the song moves on (the times follow seeks too)
            readonly property real nowMs: player.position >= 0 ? Date.now() : Date.now()
            function startsAt(index) {
                let ms = Math.max(0, (cp.s.durationMs || 0) - player.position)
                const q = player.queue
                for (let i = 0; i < index && i < q.length; i++)
                    ms += q[i].durationMs || 0
                const d = new Date(nowMs + ms / tempo)
                return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
            }

            Column {
                id: boardHead
                width: parent.width
                spacing: 6
                Label {
                    text: I18n.t("SHOWTIMES")
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2.4
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
                // the one showing now
                RowLayout {
                    width: parent.width
                    height: 64
                    spacing: 16
                    Label {
                        Layout.preferredWidth: 78
                        text: I18n.t("NOW")
                        color: cp.accent
                        font.pixelSize: 15
                        font.weight: Font.Black
                        font.letterSpacing: 2
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: (cp.s.name || I18n.t("Nothing is playing")).toUpperCase()
                            color: "#ffffff"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: cp.s.artists || ""
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: cp.serif
                            font.italic: true
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
            }
            ListView {
                id: board
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: boardHead.bottom
                anchors.bottom: parent.bottom
                clip: true
                model: cp.side && cp.panel === "queue" ? player.queue : []
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: NScrollBar {}
                SmoothScroll { flickable: board }
                Component.onCompleted: player.refreshQueue()
                delegate: Item {
                    id: show
                    required property var modelData
                    required property int index
                    width: board.width - 12
                    height: 58
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        text: showtimes.startsAt(show.index)
                        color: showHover.hovered ? cp.accent : "#ffffff"
                        font.pixelSize: 22
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                    }
                    Column {
                        x: 94
                        width: parent.width - 94 - 52
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            text: (show.modelData.name || "").toUpperCase()
                            color: showHover.hovered ? cp.accent : Qt.rgba(1, 1, 1, 0.9)
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: show.modelData.artists || ""
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: cp.serif
                            font.italic: true
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: show.modelData.durationMs ? Theme.fmt(show.modelData.durationMs) : ""
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                    HoverHandler { id: showHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: player.skip(show.index + 1) }
                }
                Label {
                    anchors.centerIn: parent
                    visible: board.count === 0
                    text: I18n.t("Nothing else is showing today")
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.family: cp.serif
                    font.italic: true
                    font.pixelSize: 16
                }
            }
        }

        EqualizerLines {
            anchors.fill: parent
            visible: cp.panel === "equalizer"
            ink: "#ffffff"
            accent: cp.accent
            family: cp.serif
        }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: cp.bottomSpace
        onCloseRequested: cp.closeRequested()
    }
}
