import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// A compact cassette drawn to scale (100 x 64 mm): smoky shell, handwritten label in the album
// art's colours, and the two reels behind the window. The tape winds from the left reel onto
// the right one with `progress`, and the reels turn at a real cassette's pace while the song
// plays (the emptier one spins faster). Used by the cassette and Walkman full views.
Item {
    id: cassette
    property bool active: true             // spin only while it is on screen
    property real progress: 0              // 0..1 through the song: how the tape is wound
    property color stripe: Theme.accent    // the label's bands
    readonly property var s: player ? player.state : ({})
    readonly property color labelInk: "#2b2a33"
    // sizes are in millimetres of a real cassette (100 x 64), times `u`
    readonly property real u: width / 100
    height: width * 0.64
    rotation: -1.5

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
        Rectangle { x: 0; y: 14.5 * cassette.u; width: parent.width; height: 2.4 * cassette.u; color: cassette.stripe }
        Rectangle { x: 0; y: 17.3 * cassette.u; width: parent.width; height: 1.1 * cassette.u; color: Qt.darker(cassette.stripe, 1.35) }

        // side letter
        Label {
            x: 2.6 * cassette.u
            y: 1.2 * cassette.u
            text: "A"
            font.pixelSize: 9 * cassette.u
            font.weight: Font.Black
            color: cassette.labelInk
        }
        // title and artist, as if written on the label by hand
        Label {
            x: 13 * cassette.u
            y: 1.2 * cassette.u
            width: 60 * cassette.u
            text: cassette.s.name || I18n.t("Nothing is playing")
            font.family: Theme.handFont
            font.pixelSize: 6.4 * cassette.u
            font.weight: Font.Bold
            color: cassette.labelInk
            elide: Text.ElideRight
        }
        Label {
            x: 13 * cassette.u
            y: 8.6 * cassette.u
            width: 60 * cassette.u
            text: cassette.s.artists || ""
            font.family: Theme.handFont
            font.pixelSize: 3.9 * cassette.u
            color: Qt.rgba(0.17, 0.16, 0.2, 0.75)
            elide: Text.ElideRight
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 2.6 * cassette.u
            y: 2.4 * cassette.u
            text: cassette.s.hasTrack ? Theme.fmt(cassette.s.durationMs || 0) : ""
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
            text: cassette.s.hasTrack ? Theme.fmt(player ? player.position : 0) : ""
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
        readonly property real leftR: Math.sqrt(hub * hub + (full * full - hub * hub) * (1 - cassette.progress))
        readonly property real rightR: Math.sqrt(hub * hub + (full * full - hub * hub) * cassette.progress)
        property real leftAngle: 0
        property real rightAngle: 0
        // 0 stopped .. 1 playing, eased so the reels spin up and slow down
        property real speed: cassette.active && cassette.s.isPlaying ? 1 : 0
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
            running: cassette.active && reels.speed > 0.01
            onTriggered: {
                const v = 38 * reels.speed * frameTime
                reels.leftAngle = (reels.leftAngle + v / reels.leftR * 180 / Math.PI) % 360
                reels.rightAngle = (reels.rightAngle + v / reels.rightR * 180 / Math.PI) % 360
            }
        }
    }

}
