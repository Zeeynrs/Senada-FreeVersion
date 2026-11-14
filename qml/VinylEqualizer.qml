import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The equalizer of the turntable full view: each band is a spoke around the record with a
// knob that slides out (louder) or in (quieter) along it, the knobs joined by a curve; 0 dB
// is the dashed arc in the middle. On the right, a turntable's pitch fader sets the tempo,
// with 33 / 45 buttons and the pitch lock. The values are the shared ones in `effects`.
// Placed inside VinylPlayer's lyrics area, which gives the geometry.
Item {
    id: veq
    property real ox            // record centre
    property real oy
    property real r0            // spokes start here

    readonly property var bands: effects.bands
    readonly property bool on: effects.enabled
    readonly property real pitchW: 120
    readonly property real pitchX: width - pitchW - 80   // clear of the volume rail
    readonly property real spokeLen: Math.max(160, Math.min(460, pitchX - 120 - (ox + r0)))
    // the outer spokes open as far as the labels at their ends stay clear of the top and the controls
    readonly property real spread: {
        const room = Math.min(oy, height - oy) - 44
        const a = Math.asin(Math.max(0, Math.min(1, room / (r0 + spokeLen + 60)))) * 180 / Math.PI
        return Math.max(12, Math.min(25, a))
    }
    readonly property var angles: [0, 1, 2, 3, 4, 5].map(i => -spread + i * spread * 2 / 5)
    readonly property real mid: r0 + spokeLen / 2
    readonly property color accent: Theme.accent
    function knobR(gain) { return mid + gain * spokeLen / 2 }

    // ---- heading: name, preset, on/off (top right, clear of the spokes) -------------------------
    Row {
        x: veq.width - width - 80
        y: 8
        spacing: 12
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("Equalizer")
            color: "#ffffff"
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: presetText.implicitWidth + 24
            implicitHeight: 28
            width: implicitWidth
            height: implicitHeight
            radius: 14
            color: presetHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.12)
            Label {
                id: presetText
                anchors.centerIn: parent
                text: I18n.t(effects.preset) + "  ↻"
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            HoverHandler { id: presetHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: effects.nextPreset() }
            ToolTip.visible: presetHover.hovered
            ToolTip.delay: 500
            ToolTip.text: I18n.t("Next preset")
        }
        Rectangle {  // on / off
            anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 26; radius: 13
            color: veq.on ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
            Rectangle {
                width: 20; height: 20; radius: 10
                anchors.verticalCenter: parent.verticalCenter
                x: veq.on ? parent.width - width - 3 : 3
                color: veq.on ? "#1b1d22" : "#c9ccd2"
                Behavior on x { NumberAnimation { duration: 140 } }
            }
            HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: effects.setEnabled(!veq.on) }
            ToolTip.visible: powerHover.hovered
            ToolTip.delay: 500
            ToolTip.text: veq.on ? I18n.t("Turn the equalizer off") : I18n.t("Turn the equalizer on")
        }
    }

    // ---- the curve through the knobs, and the 0 dB arc ----------------------------------------
    Canvas {
        id: curve
        anchors.fill: parent
        opacity: veq.on ? 1 : 0.4
        property var gains: veq.bands
        onGainsChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const rad = a => a * Math.PI / 180
            // 0 dB arc, dashed
            ctx.strokeStyle = "rgba(255,255,255,0.22)"
            ctx.lineWidth = 1.2
            ctx.setLineDash([4, 6])
            ctx.beginPath()
            ctx.arc(veq.ox, veq.oy, veq.mid, rad(veq.angles[0] - 4), rad(veq.angles[5] + 4))
            ctx.stroke()
            ctx.setLineDash([])
            // the curve through the knobs
            const pts = veq.angles.map((a, i) => {
                const r = veq.knobR(gains[i] || 0)
                return [veq.ox + r * Math.cos(rad(a)), veq.oy + r * Math.sin(rad(a))]
            })
            const c = veq.accent
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.9)
            ctx.lineWidth = 2.5
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(pts[0][0], pts[0][1])
            for (let i = 1; i < pts.length - 1; i++) {
                const mx = (pts[i][0] + pts[i + 1][0]) / 2, my = (pts[i][1] + pts[i + 1][1]) / 2
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my)
            }
            ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1])
            ctx.stroke()
        }
    }

    // ---- one spoke per band ----------------------------------------------------------------
    Repeater {
        model: 6
        Item {
            id: spoke
            required property int index
            readonly property real gain: veq.bands[index] || 0
            readonly property real kx: veq.knobR(gain)
            x: veq.ox
            y: veq.oy
            rotation: veq.angles[index]
            opacity: veq.on ? 1 : 0.45

            Rectangle {  // track
                x: veq.r0
                y: -1.5
                width: veq.spokeLen
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.18)
            }
            Rectangle {  // from 0 dB to the knob
                x: Math.min(veq.mid, spoke.kx)
                y: -1.5
                width: Math.abs(spoke.kx - veq.mid)
                height: 3
                color: veq.accent
            }
            Rectangle {  // 0 dB tick
                x: veq.mid - 1
                y: -8
                width: 2
                height: 16
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.35)
            }
            Rectangle {  // knob
                x: spoke.kx - width / 2
                y: -height / 2
                width: drag.pressed || drag.containsMouse ? 24 : 20
                height: width
                radius: width / 2
                color: "#ffffff"
                border.width: 3
                border.color: veq.accent
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            Column {  // band and gain past the end of the spoke
                x: veq.r0 + veq.spokeLen + 16
                y: -height / 2
                Label {
                    text: effects.bandLabels[spoke.index] + " Hz"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Label {
                    text: (spoke.gain >= 0 ? "+" : "") + (spoke.gain * 12).toFixed(1) + " dB"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
            }
            MouseArea {
                id: drag
                x: veq.r0 - 14
                y: -18
                width: veq.spokeLen + 28
                height: 36
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                // along the spoke is simply x here, whatever the angle
                function set(mx) { effects.setBand(spoke.index, (mx + x - veq.mid) / (veq.spokeLen / 2)) }
                onPressed: (mouse) => set(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) set(mouse.x) }
                onDoubleClicked: effects.setBand(spoke.index, 0)
                onWheel: (wheel) => effects.setBand(spoke.index, spoke.gain + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
    }

    // ---- pitch fader, like on a turntable --------------------------------------------------------
    Column {
        id: pitch
        x: veq.pitchX
        width: veq.pitchW
        y: veq.oy - height / 2
        spacing: 12
        readonly property real travel: Math.max(140, Math.min(320, veq.height * 0.48))
        // 0.5x at the bottom, 2x at the top, 1x in the middle
        function pos(t) { return t <= 1 ? (t - 0.5) : 0.5 + (t - 1) / 2 }
        function tempoAt(p) { return p <= 0.5 ? 0.5 + p : 1 + (p - 0.5) * 2 }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("TEMPO")
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 2.4
        }
        Item {
            id: slot
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80
            height: pitch.travel + 30
            Repeater {  // scale
                model: [["2×", 1], ["1.5×", 0.75], ["1×", 0.5], ["0.75×", 0.25], ["0.5×", 0]]
                Item {
                    required property var modelData
                    y: 15 + (1 - modelData[1]) * pitch.travel
                    Rectangle { x: 30; width: 20; height: 1; color: Qt.rgba(1, 1, 1, modelData[1] === 0.5 ? 0.6 : 0.25) }
                    Label {
                        x: 56
                        y: -height / 2
                        text: modelData[0]
                        color: Qt.rgba(1, 1, 1, modelData[1] === 0.5 ? 0.8 : 0.45)
                        font.pixelSize: 11
                    }
                }
            }
            Rectangle {  // the slot
                x: 36
                y: 10
                width: 8
                height: pitch.travel + 10
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.15)
            }
            Rectangle {  // fader cap
                x: 22
                y: 15 + (1 - pitch.pos(effects.tempo)) * pitch.travel - height / 2
                width: 36
                height: 22
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f4f4f6" }
                    GradientStop { position: 1; color: "#a9adb4" }
                }
                border.color: "#55585e"
                Rectangle { anchors.centerIn: parent; width: parent.width - 8; height: 2; color: veq.accent }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                preventStealing: true
                function set(my) {
                    const p = Math.max(0, Math.min(1, 1 - (my - 15) / pitch.travel))
                    const t = pitch.tempoAt(p)
                    effects.setTempo(Math.abs(t - 1) < 0.04 ? 1 : Math.round(t * 20) / 20)
                }
                onPressed: (mouse) => set(mouse.y)
                onPositionChanged: (mouse) => { if (pressed) set(mouse.y) }
                onDoubleClicked: effects.setTempo(1)
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: effects.tempo.toFixed(2) + "×"
            color: "#ffffff"
            font.pixelSize: 16
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        // 33 / 45: a record's two speeds (45 is 1.35 times 33⅓)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: [["33", 1.0], ["45", 1.35]]
                Rectangle {
                    required property var modelData
                    readonly property bool lit: Math.abs(effects.tempo - modelData[1]) < 0.01
                    width: 44; height: 30; radius: 6
                    color: lit ? "#ffffff" : rpmHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    Label {
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: parent.lit ? "#1b1d22" : "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                    HoverHandler { id: rpmHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: effects.setTempo(modelData[1]) }
                    ToolTip.visible: rpmHover.hovered
                    ToolTip.delay: 500
                    ToolTip.text: modelData[0] === "45" ? I18n.t("45 rpm: 1.35× faster") : I18n.t("33⅓ rpm: normal speed")
                }
            }
        }
        // pitch lock
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: lockRow.implicitWidth + 20
            height: 30
            radius: 15
            color: lockHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
            border.color: Qt.rgba(1, 1, 1, 0.2)
            Row {
                id: lockRow
                anchors.centerIn: parent
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: effects.keepPitch ? "#ffbf3c" : Qt.rgba(1, 1, 1, 0.25)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("PITCH LOCK")
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
            }
            HoverHandler { id: lockHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: effects.setKeepPitch(!effects.keepPitch) }
            ToolTip.visible: lockHover.hovered
            ToolTip.delay: 500
            ToolTip.text: effects.keepPitch ? I18n.t("Keep original pitch: on") : I18n.t("Speed also changes the key, just like sped-up or slowed-down songs.")
        }
    }
}
