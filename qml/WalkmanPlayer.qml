import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a portable cassette player (Settings → Appearance → Full view style): a metal
// body with the cassette turning behind its smoked window, real keys along the top (stop,
// play, rewind, fast-forward: they work and stay down like the real thing), a volume wheel on
// the side, a bass boost switch and the headphone cable. Beside it, as with the cassette view:
// the lyrics or the track list on paper, or the tape deck's equalizer. Controls along the bottom.
Item {
    id: wp
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
    readonly property int volume: (s.volume !== undefined && s.volume >= 0) ? s.volume : 80

    readonly property real stageW: showPanel ? width * 0.58 : width
    // body 100 x 74, with room above for the keys
    readonly property real bodyW: Math.max(300, Math.min(stageW * 0.8, (areaH - 40) / 0.74 * 0.92, 900))

    // ---- the player ------------------------------------------------------------------------
    Item {
        id: walkman
        readonly property real u: width / 100
        width: wp.bodyW
        height: width * 0.74
        x: (wp.stageW - width) / 2 + (wp.showPanel ? 24 : 0)
        y: wp.topSpace + (wp.areaH - height) / 2 + 3 * u
        rotation: -2
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        // headphone cable, from the jack up and away
        Canvas {
            x: 78 * walkman.u
            y: -40 * walkman.u
            width: 30 * walkman.u
            height: 44 * walkman.u
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#1b1c20"
                ctx.lineWidth = Math.max(3, 0.9 * walkman.u)
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(8 * walkman.u, height - 1)
                ctx.bezierCurveTo(8 * walkman.u, height * 0.4, 26 * walkman.u, height * 0.55, 22 * walkman.u, 0)
                ctx.stroke()
            }
        }

        // keys along the top edge: stop, play, rewind, fast-forward
        Row {
            x: 10 * walkman.u
            y: -5.5 * walkman.u
            spacing: 1.2 * walkman.u
            Repeater {
                model: [
                    { glyph: "■", tip: "Pause", act: "stop" },
                    { glyph: "▶", tip: "Play", act: "play" },
                    { glyph: "◀◀", tip: "Previous (Ctrl+←)", act: "rew" },
                    { glyph: "▶▶", tip: "Next (Ctrl+→)", act: "ff" }
                ]
                Item {
                    id: key
                    required property var modelData
                    readonly property bool latched: modelData.act === "play" && !!wp.s.isPlaying
                    readonly property bool down: tap.pressed || latched
                    width: 13 * walkman.u
                    height: 8 * walkman.u
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        y: key.down ? 2.2 * walkman.u : 0
                        radius: 1.2 * walkman.u
                        gradient: Gradient {
                            GradientStop { position: 0; color: key.down ? "#8d939c" : "#c9ced6" }
                            GradientStop { position: 1; color: key.down ? "#5d636c" : "#868c96" }
                        }
                        border.color: "#3e434b"
                        Behavior on y { NumberAnimation { duration: 90 } }
                        Label {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -0.8 * walkman.u
                            text: key.modelData.glyph
                            color: key.modelData.act === "play" ? "#2f7d4a" : "#2d3138"
                            font.pixelSize: 3 * walkman.u
                            font.weight: Font.Black
                        }
                    }
                    TapHandler {
                        id: tap
                        onTapped: {
                            const a = key.modelData.act
                            if (a === "stop") { if (wp.s.isPlaying) player.togglePlay() }
                            else if (a === "play") { if (!wp.s.isPlaying) player.togglePlay() }
                            else if (a === "rew") player.previous()
                            else player.next()
                        }
                    }
                    HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: keyHover.hovered
                    ToolTip.delay: 500
                    ToolTip.text: I18n.t(key.modelData.tip)
                }
            }
        }

        // shadow
        Rectangle {
            id: bodyShape
            anchors.fill: parent
            radius: 6 * walkman.u
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: bodyShape
            source: bodyShape
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.7
            shadowBlur: 1.0
            shadowVerticalOffset: 18
            shadowHorizontalOffset: 6
        }
        // brushed metal body in the album art's colour
        Rectangle {
            id: body
            anchors.fill: parent
            radius: 6 * walkman.u
            readonly property color tint: Qt.tint("#8a96a6", Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35))
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(body.tint, 1.25) }
                GradientStop { position: 0.5; color: body.tint }
                GradientStop { position: 1; color: Qt.darker(body.tint, 1.35) }
            }
            border.color: Qt.darker(body.tint, 2)
        }
        Canvas {  // brushed lines
            anchors.fill: parent
            anchors.margins: walkman.u
            opacity: 0.5
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                for (let y = 0; y < height; y += 2) {
                    const a = 0.02 + 0.03 * Math.abs(Math.sin(y * 12.9898) * 43758.5453 % 1)
                    ctx.fillStyle = (y % 4 === 0 ? "rgba(255,255,255," : "rgba(0,0,0,") + a.toFixed(3) + ")"
                    ctx.fillRect(0, y, width, 1)
                }
            }
        }
        // engraved text
        Label {
            x: 6 * walkman.u
            y: 3.5 * walkman.u
            text: "SENADA"
            color: Qt.rgba(0.1, 0.11, 0.13, 0.75)
            style: Text.Raised
            styleColor: Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize: 4.2 * walkman.u
            font.weight: Font.Black
            font.letterSpacing: 1.2 * walkman.u
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 7 * walkman.u
            y: 4.6 * walkman.u
            text: "STEREO CASSETTE PLAYER  ·  AUTO REVERSE"
            color: Qt.rgba(0.1, 0.11, 0.13, 0.6)
            font.pixelSize: 1.9 * walkman.u
            font.weight: Font.Bold
            font.letterSpacing: 0.3 * walkman.u
        }

        // the cassette behind the smoked window
        Item {
            id: tapeWindow
            x: 6 * walkman.u
            y: 10 * walkman.u
            width: 88 * walkman.u
            height: 54 * walkman.u
            Rectangle {
                anchors.fill: parent
                radius: 3 * walkman.u
                color: "#15171b"
                border.color: Qt.rgba(0, 0, 0, 0.6)
                border.width: Math.max(1, 0.5 * walkman.u)
            }
            CassetteTape {
                anchors.centerIn: parent
                width: parent.width * 0.88
                active: wp.active
                progress: wp.progress
                rotation: 0
            }
            Rectangle {  // smoked glass with a glare
                anchors.fill: parent
                radius: 3 * walkman.u
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.14) }
                    GradientStop { position: 0.35; color: Qt.rgba(0.05, 0.05, 0.08, 0.18) }
                    GradientStop { position: 1; color: Qt.rgba(0.05, 0.05, 0.08, 0.3) }
                }
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }
            HoverHandler { cursorShape: wp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (wp.s.hasTrack) player.togglePlay() }
        }

        // bass boost slide switch
        Item {
            id: bass
            readonly property bool on: effects.enabled && effects.preset === "Bass Boost"
            x: 6 * walkman.u
            y: 66.5 * walkman.u
            width: 26 * walkman.u
            height: 5 * walkman.u
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "BASS BOOST"
                color: Qt.rgba(0.1, 0.11, 0.13, 0.75)
                font.pixelSize: 1.9 * walkman.u
                font.weight: Font.Black
                font.letterSpacing: 0.25 * walkman.u
            }
            Rectangle {
                id: slot
                x: 15 * walkman.u
                anchors.verticalCenter: parent.verticalCenter
                width: 9 * walkman.u
                height: 3 * walkman.u
                radius: height / 2
                color: "#1a1c20"
                Rectangle {
                    width: parent.width / 2
                    height: parent.height - 0.6 * walkman.u
                    anchors.verticalCenter: parent.verticalCenter
                    x: bass.on ? parent.width - width - 0.3 * walkman.u : 0.3 * walkman.u
                    radius: height / 2
                    color: bass.on ? "#ff8a3d" : "#c9ced6"
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (bass.on) effects.usePreset("Flat")
                    else { effects.usePreset("Bass Boost"); effects.setEnabled(true) }
                }
            }
        }
        // headphone jack and a little lamp that glows while playing
        Rectangle {
            x: 84 * walkman.u
            y: -0.8 * walkman.u
            width: 4 * walkman.u
            height: 2 * walkman.u
            radius: walkman.u
            color: "#1b1c20"
        }
        Rectangle {
            x: 88 * walkman.u
            y: 67.5 * walkman.u
            width: 2 * walkman.u
            height: width
            radius: width / 2
            color: wp.s.isPlaying ? "#ff4b3a" : "#5a2420"
            Rectangle {
                anchors.centerIn: parent
                visible: wp.s.isPlaying
                width: parent.width * 2.4
                height: width
                radius: width / 2
                color: Qt.rgba(1, 0.3, 0.23, 0.25)
            }
        }

        // volume wheel sticking out of the right side
        Item {
            id: wheel
            x: walkman.width - 1.2 * walkman.u
            y: 22 * walkman.u
            width: 4.5 * walkman.u
            height: 28 * walkman.u
            Rectangle {
                anchors.fill: parent
                radius: 1.2 * walkman.u
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#2a2d33" }
                    GradientStop { position: 1; color: "#5b6069" }
                }
            }
            // ridges that slide as the volume changes
            Item {
                anchors.fill: parent
                clip: true
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        x: 0.4 * walkman.u
                        width: wheel.width - 0.8 * walkman.u
                        height: Math.max(1, 0.35 * walkman.u)
                        y: ((index * wheel.height / 14) + wp.volume / 100 * wheel.height / 14 * 6) % (wheel.height + 2)
                        color: Qt.rgba(1, 1, 1, 0.3)
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -walkman.u
                cursorShape: Qt.SizeVerCursor
                preventStealing: true
                property real startY: 0
                property int startVol: 0
                onPressed: (mouse) => { startY = mouse.y; startVol = wp.volume }
                onPositionChanged: (mouse) => { if (pressed) player.setVolume(Math.max(0, Math.min(100, Math.round(startVol + (startY - mouse.y) / 2)))) }
                onWheel: (w) => player.setVolume(Math.max(0, Math.min(100, wp.volume + (w.angleDelta.y > 0 ? 5 : -5))))
            }
            ToolTip.visible: volHover.hovered
            ToolTip.delay: 400
            ToolTip.text: I18n.t("Volume") + " " + wp.volume + "%"
            HoverHandler { id: volHover }
        }
    }

    // ---- beside the player: lyrics, the track list or the deck's equalizer --------------------
    component Side: Item {
        property bool open
        visible: opacity > 0
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
    readonly property rect sideRect: Qt.rect(width * 0.6, topSpace + 6, width * 0.4 - 48, areaH - 12)
    Side {
        open: wp.showPanel && wp.panel === "lyrics"
        x: wp.sideRect.x; y: wp.sideRect.y; width: wp.sideRect.width; height: wp.sideRect.height
        LyricsPaper { anchors.fill: parent }
    }
    Side {
        open: wp.showPanel && wp.panel === "queue"
        x: wp.sideRect.x; y: wp.sideRect.y; width: wp.sideRect.width; height: wp.sideRect.height
        TracklistPaper { anchors.fill: parent }
    }
    Side {
        open: wp.showPanel && wp.panel === "equalizer"
        x: wp.sideRect.x; y: wp.sideRect.y; width: wp.sideRect.width; height: wp.sideRect.height
        DeckEqualizer { anchors.fill: parent; active: wp.active && parent.visible }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: wp.bottomSpace
        onCloseRequested: wp.closeRequested()
    }
}
