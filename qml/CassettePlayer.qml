import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a cassette (Settings → Appearance → Full view style). The tape winds from the
// left reel onto the right one as the song plays, so the reels show how far along it is; the
// reels turn at a real cassette's pace (the emptier one spins faster). Beside it: the lyrics
// written on a ruled paper card (the sung line marked with a highlighter), the queue as a
// mixtape's handwritten track list, or the equalizer as a tape deck's front panel. Clicking
// the cassette plays / pauses. The controls sit in a strip along the bottom.
Item {
    id: cp
    property bool active: true            // the full view is on screen
    property string panel: "lyrics"       // "lyrics" | "queue" | "equalizer"
    property bool showPanel: true
    signal closeRequested()
    readonly property var s: player ? player.state : ({})

    readonly property real topSpace: 68
    readonly property real bottomSpace: 116
    readonly property real areaH: height - topSpace - bottomSpace
    readonly property real durationMs: Math.max(1, s.durationMs || 0)
    readonly property real progress: s.hasTrack ? Math.max(0, Math.min(1, (player ? player.position : 0) / durationMs)) : 0

    // a handwriting font for the label and the lyrics card, where the system has one
    readonly property string handFont: {
        const have = Qt.fontFamilies()
        for (const name of ["Ink Free", "Segoe Print", "Comic Neue", "Comic Sans MS"])
            if (have.indexOf(name) >= 0)
                return name
        return ""
    }
    readonly property color labelInk: "#2b2a33"
    readonly property color stripe: Theme.accent

    // ---- where things go -------------------------------------------------------------------
    // with something open on the right the cassette takes the left part, else the middle
    readonly property real stageW: showPanel ? width * 0.58 : width
    readonly property real cassetteW: Math.max(260, Math.min(stageW * 0.84, areaH * 0.88 * 1.57, 980))
    readonly property real cassetteX: (stageW - cassetteW) / 2 + (showPanel ? 24 : 0)

    // ---- the cassette ------------------------------------------------------------------------
    Item {
        id: cassette
        // sizes are in millimetres of a real cassette (100 x 64), times `u`
        readonly property real u: width / 100
        x: cp.cassetteX
        y: cp.topSpace + (cp.areaH - height) / 2
        width: cp.cassetteW
        height: width * 0.64
        rotation: -1.5
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        // shadow (drawn once; the cassette itself redraws as the reels turn)
        Rectangle {
            id: shadowShape
            anchors.fill: parent
            radius: 4 * cassette.u
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: shadowShape
            source: shadowShape
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.65
            shadowBlur: 1.0
            shadowVerticalOffset: 16
            shadowHorizontalOffset: 6
            opacity: 0.9
        }

        // smoky plastic shell
        Rectangle {
            anchors.fill: parent
            radius: 4 * cassette.u
            gradient: Gradient {
                GradientStop { position: 0; color: "#34343c" }
                GradientStop { position: 1; color: "#18181d" }
            }
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
        }
        // screws
        Repeater {
            model: [[4.2, 4.2], [95.8, 4.2], [4.2, 59.8], [95.8, 59.8], [50, 57]]
            Rectangle {
                required property var modelData
                x: (modelData[0] - 1.7) * cassette.u
                y: (modelData[1] - 1.7) * cassette.u
                width: 3.4 * cassette.u
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#bdbdc4" }
                    GradientStop { position: 1; color: "#5c5c64" }
                }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.7; height: Math.max(1, parent.width * 0.14); color: "#3b3b42"; rotation: 35 }
            }
        }

        // the lower part where the tape passes the head: a raised strip with its holes
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                const u = cassette.u
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(17 * u, 64 * u); ctx.lineTo(21 * u, 47 * u); ctx.lineTo(79 * u, 47 * u); ctx.lineTo(83 * u, 64 * u)
                ctx.closePath()
                ctx.fillStyle = "rgba(255,255,255,0.05)"
                ctx.fill()
                ctx.strokeStyle = "rgba(255,255,255,0.12)"
                ctx.lineWidth = 1
                ctx.stroke()
                // the tape running along the bottom edge
                ctx.strokeStyle = "#5a3d2c"
                ctx.lineWidth = Math.max(1.5, 0.9 * u)
                ctx.beginPath(); ctx.moveTo(21 * u, 61.6 * u); ctx.lineTo(79 * u, 61.6 * u); ctx.stroke()
                // capstan and guide holes
                ctx.fillStyle = "#0b0b0e"
                for (const [hx, hy, r] of [[31, 55.5, 2.1], [69, 55.5, 2.1], [40, 57, 1.1], [60, 57, 1.1]]) {
                    ctx.beginPath(); ctx.arc(hx * u, hy * u, r * u, 0, 2 * Math.PI); ctx.fill()
                }
                for (const hx of [24, 46, 76]) {
                    ctx.fillRect((hx - 1.6) * u, 58.5 * u, 3.2 * u, 3.2 * u)
                }
            }
        }

        // ---- the label ----
        Rectangle {
            id: label
            x: 6 * cassette.u
            y: 5 * cassette.u
            width: 88 * cassette.u
            height: 39 * cassette.u
            radius: 2 * cassette.u
            color: "#efe7d4"

            // coloured bands in the album art's colour
            Rectangle { x: 0; y: 14.5 * cassette.u; width: parent.width; height: 2.4 * cassette.u; color: cp.stripe }
            Rectangle { x: 0; y: 17.3 * cassette.u; width: parent.width; height: 1.1 * cassette.u; color: Qt.darker(cp.stripe, 1.35) }

            // side letter
            Label {
                x: 2.6 * cassette.u
                y: 1.2 * cassette.u
                text: "A"
                font.pixelSize: 9 * cassette.u
                font.weight: Font.Black
                color: cp.labelInk
            }
            // title and artist, as if written on the label by hand
            Label {
                x: 13 * cassette.u
                y: 1.2 * cassette.u
                width: 60 * cassette.u
                text: cp.s.name || I18n.t("Nothing is playing")
                font.family: cp.handFont
                font.pixelSize: 6.4 * cassette.u
                font.weight: Font.Bold
                color: cp.labelInk
                elide: Text.ElideRight
            }
            Label {
                x: 13 * cassette.u
                y: 8.6 * cassette.u
                width: 60 * cassette.u
                text: cp.s.artists || ""
                font.family: cp.handFont
                font.pixelSize: 3.9 * cassette.u
                color: Qt.rgba(0.17, 0.16, 0.2, 0.75)
                elide: Text.ElideRight
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 2.6 * cassette.u
                y: 2.4 * cassette.u
                text: cp.s.hasTrack ? Theme.fmt(cp.s.durationMs || 0) : ""
                font.pixelSize: 3.6 * cassette.u
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Qt.rgba(0.17, 0.16, 0.2, 0.7)
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 2.6 * cassette.u
                y: 8.2 * cassette.u
                text: "C60 · Type I"
                font.pixelSize: 2.6 * cassette.u
                font.letterSpacing: 0.3 * cassette.u
                color: Qt.rgba(0.17, 0.16, 0.2, 0.5)
            }
            // elapsed time written under the window
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 35.2 * cassette.u
                text: cp.s.hasTrack ? Theme.fmt(player ? player.position : 0) : ""
                font.pixelSize: 2.8 * cassette.u
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Qt.rgba(0.17, 0.16, 0.2, 0.6)
            }
        }

        // ---- the window with the two reels ----
        Item {
            id: reels
            readonly property real hub: 5.6               // hub radius (mm)
            readonly property real full: 18.5             // radius of a reel holding all the tape
            // tape moves from left to right; the area of tape on a reel follows the song
            readonly property real leftR: Math.sqrt(hub * hub + (full * full - hub * hub) * (1 - cp.progress))
            readonly property real rightR: Math.sqrt(hub * hub + (full * full - hub * hub) * cp.progress)
            property real leftAngle: 0
            property real rightAngle: 0
            // 0 stopped .. 1 playing, eased so the reels spin up and slow down
            property real speed: cp.active && cp.s.isPlaying ? 1 : 0
            Behavior on speed { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

            x: 19 * cassette.u
            y: 20 * cassette.u
            width: 62 * cassette.u
            height: 18 * cassette.u

            Rectangle {   // the clear window
                id: windowShape
                anchors.fill: parent
                radius: height / 2
                color: "#0d0d10"
                border.color: Qt.rgba(0, 0, 0, 0.6)
                border.width: Math.max(1, 0.5 * cassette.u)
            }
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: windowMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        readonly property real r: (index === 0 ? reels.leftR : reels.rightR) * cassette.u
                        // hub centres are 42.5 mm apart, in the middle of the window
                        x: (index === 0 ? 50 - 21.25 : 50 + 21.25) * cassette.u - reels.x
                        y: 29 * cassette.u - reels.y
                        // wound tape
                        Rectangle {
                            x: -width / 2
                            y: -height / 2
                            width: parent.r * 2
                            height: width
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#6b4a35" }
                                GradientStop { position: 1; color: "#3c281c" }
                            }
                            border.color: Qt.rgba(0, 0, 0, 0.35)
                        }
                        // hub with its teeth, turning
                        Item {
                            rotation: index === 0 ? reels.leftAngle : reels.rightAngle
                            Rectangle {
                                x: -width / 2
                                y: -height / 2
                                width: reels.hub * 2 * cassette.u
                                height: width
                                radius: width / 2
                                color: "#ecebe6"
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.62
                                    height: width
                                    radius: width / 2
                                    color: "#0d0d10"
                                }
                            }
                            Repeater {
                                model: 6
                                Rectangle {
                                    required property int index
                                    readonly property real rr: reels.hub * 0.62 * cassette.u
                                    x: -width / 2
                                    y: -rr
                                    width: Math.max(2, 1.1 * cassette.u)
                                    height: Math.max(3, 1.4 * cassette.u)
                                    color: "#ecebe6"
                                    transform: Rotation { origin.x: width / 2; origin.y: rr; angle: index * 60 }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: windowMask
                anchors.fill: parent
                radius: height / 2
                visible: false
                layer.enabled: true
            }
            // plastic glare over the window
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }

            // a real cassette moves 47.6 mm of tape a second; slowed a little to look calm
            FrameAnimation {
                running: cp.active && reels.speed > 0.01
                onTriggered: {
                    const v = 38 * reels.speed * frameTime
                    reels.leftAngle = (reels.leftAngle + v / reels.leftR * 180 / Math.PI) % 360
                    reels.rightAngle = (reels.rightAngle + v / reels.rightR * 180 / Math.PI) % 360
                }
            }
        }

        HoverHandler { cursorShape: cp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (cp.s.hasTrack) player.togglePlay() }
    }

    // ---- the right-hand side: lyrics, the track list or the deck's equalizer ---------------------
    // all three take the same place beside the cassette
    // (an inline component cannot see `cp`, so each use places itself)
    component Side: Item {
        property bool open
        visible: opacity > 0
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
    readonly property rect sideRect: Qt.rect(width * 0.6, topSpace + 6, width * 0.4 - 48, areaH - 12)

    // lyrics on a ruled paper card, the sung line marked with a highlighter
    Side {
        open: cp.showPanel && cp.panel === "lyrics"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        PaperCard {
            id: card
            readonly property real lineGap: 8
            anchors.fill: parent
            handFont: cp.handFont
            title: I18n.t("Lyrics") + (cp.s.name ? " — " + cp.s.name : "")

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
                        font.family: cp.handFont
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
                    font.family: cp.handFont
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
    }

    // the queue as a mixtape's handwritten track list
    Side {
        open: cp.showPanel && cp.panel === "queue"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        PaperCard {
            id: listCard
            anchors.fill: parent
            handFont: cp.handFont
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
                    height: cp.s.hasTrack ? 52 : 0
                    visible: cp.s.hasTrack
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
                        text: "♪  " + (cp.s.name || "") + (cp.s.artists ? " — " + cp.s.artists : "")
                        font.family: cp.handFont
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: listCard.ink
                        elide: Text.ElideRight
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        y: 14
                        text: Theme.fmt(cp.s.durationMs || 0)
                        font.family: cp.handFont
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
                        font.family: cp.handFont
                        font.pixelSize: 16
                        color: Qt.rgba(0.85, 0.3, 0.3, 0.75)
                    }
                    Label {
                        x: listCard.textX
                        width: parent.width - listCard.textX - 70
                        anchors.verticalCenter: parent.verticalCenter
                        text: (trackRow.modelData.name || "") + (trackRow.modelData.artists ? " — " + trackRow.modelData.artists : "")
                        font.family: cp.handFont
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
                        font.family: cp.handFont
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
                    font.family: cp.handFont
                    font.pixelSize: 18
                    color: Qt.rgba(0.15, 0.15, 0.19, 0.55)
                }
            }
        }
    }

    // the equalizer as a hi-fi tape deck's front panel
    Side {
        open: cp.showPanel && cp.panel === "equalizer"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        DeckEqualizer {
            anchors.fill: parent
            active: cp.active && parent.visible
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
