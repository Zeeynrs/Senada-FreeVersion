import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// The equalizer of the cassette full view, drawn as a hi-fi tape deck's front panel: brushed
// aluminium, an LED level meter over each band, slide faders with chrome caps, a tape speed
// fader and a pitch lock button. The values are the shared ones in `effects`.
Item {
    id: deck
    property bool active: true
    readonly property var bands: effects.bands
    readonly property bool on: effects.enabled
    readonly property int segments: 14

    // ---- live levels for the meter: the spectrum folded into the six bands -------------------
    property var levels: [0, 0, 0, 0, 0, 0]
    property real clock: 0
    FrameAnimation {
        running: deck.active && deck.visible
        onTriggered: {
            const dt = Math.min(0.05, frameTime)
            deck.clock += dt
            const raw = visualizer ? (visualizer.bars || []) : []
            const playing = player && player.state ? !!player.state.isPlaying : false
            const live = visualizer && visualizer.active && raw.length >= 6
            const out = []
            for (let b = 0; b < 6; b++) {
                let v = 0
                if (live) {
                    const from = Math.floor(b * raw.length / 6), to = Math.floor((b + 1) * raw.length / 6)
                    for (let i = from; i < to; i++) v = Math.max(v, raw[i] || 0)
                } else if (playing) {  // no cava: a gentle stand-in so the meter is not dead
                    v = 0.45 + 0.3 * Math.sin(deck.clock * (2.1 + b * 0.7) + b) * Math.sin(deck.clock * 1.3 + b * 2.0)
                }
                v = Math.max(0, Math.min(1, v * (deck.on ? 1 + 0.35 * (deck.bands[b] || 0) : 0.3)))
                const prev = deck.levels[b] || 0
                out.push(v > prev ? prev + (v - prev) * 0.6 : prev + (v - prev) * Math.min(1, dt * 6))
            }
            deck.levels = out
        }
    }

    // ---- the panel ------------------------------------------------------------------------------
    Rectangle {
        id: plateShape
        anchors.fill: parent
        radius: 10
        color: "black"
        visible: false
    }
    MultiEffect {
        anchors.fill: plateShape
        source: plateShape
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.6
        shadowBlur: 0.9
        shadowVerticalOffset: 12
    }
    Rectangle {
        anchors.fill: parent
        radius: 10
        gradient: Gradient {
            GradientStop { position: 0; color: "#dfe1e5" }
            GradientStop { position: 0.5; color: "#c3c6cc" }
            GradientStop { position: 1; color: "#a6aab1" }
        }
        border.color: "#6f737a"
    }
    Canvas {  // brushed metal
        anchors.fill: parent
        anchors.margins: 2
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            for (let y = 0; y < height; y += 2) {
                const a = 0.025 + 0.03 * Math.abs(Math.sin(y * 12.9898) * 43758.5453 % 1)
                ctx.fillStyle = (y % 4 === 0 ? "rgba(255,255,255," : "rgba(0,0,0,") + a.toFixed(3) + ")"
                ctx.fillRect(0, y, width, 1)
            }
        }
    }
    Repeater {  // screws
        model: [[14, 14], [1, 14], [14, 1], [1, 1]]
        Rectangle {
            required property var modelData
            x: modelData[0] === 14 ? 10 : deck.width - 20
            y: modelData[1] === 14 ? 10 : deck.height - 20
            width: 10; height: 10; radius: 5
            gradient: Gradient {
                GradientStop { position: 0; color: "#f2f2f4" }
                GradientStop { position: 1; color: "#7c7f86" }
            }
            Rectangle { anchors.centerIn: parent; width: 7; height: 1.4; color: "#5b5e64"; rotation: 40 }
        }
    }

    // engraved text
    component Engraved: Label {
        color: "#3c3f45"
        style: Text.Raised
        styleColor: Qt.rgba(1, 1, 1, 0.55)
        font.weight: Font.Bold
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        anchors.topMargin: 22
        spacing: 14

        // ---- header: name, preset, power ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Column {
                spacing: 1
                Engraved { text: "SENADA"; font.pixelSize: 17; font.letterSpacing: 4 }
                Engraved { text: I18n.t("GRAPHIC EQUALIZER"); font.pixelSize: 10; font.letterSpacing: 2.2; opacity: 0.8 }
            }
            Item { Layout.fillWidth: true }
            // preset button: a black push button with the preset's name
            AbstractButton {
                id: presetButton
                implicitWidth: presetLabel.implicitWidth + 28
                implicitHeight: 30
                onClicked: effects.nextPreset()
                background: Rectangle {
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0; color: presetButton.down ? "#1a1a1d" : "#3a3a3f" }
                        GradientStop { position: 1; color: "#141416" }
                    }
                    border.color: "#0b0b0c"
                }
                contentItem: Label {
                    id: presetLabel
                    text: I18n.t(effects.preset)
                    color: "#e9e9ec"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: I18n.t("Next preset")
            }
            // power: round button with a lamp
            AbstractButton {
                id: power
                implicitWidth: 64
                implicitHeight: 30
                onClicked: effects.setEnabled(!deck.on)
                background: Rectangle {
                    radius: 15
                    gradient: Gradient {
                        GradientStop { position: 0; color: power.down ? "#1a1a1d" : "#3a3a3f" }
                        GradientStop { position: 1; color: "#141416" }
                    }
                    border.color: "#0b0b0c"
                }
                contentItem: Row {
                    spacing: 7
                    leftPadding: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 4.5
                        color: deck.on ? "#5cf08a" : "#5a1f1f"
                        border.color: Qt.rgba(0, 0, 0, 0.5)
                        Rectangle {  // glow
                            anchors.centerIn: parent
                            visible: deck.on
                            width: 18; height: 18; radius: 9
                            color: Qt.rgba(0.36, 0.94, 0.54, 0.25)
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: deck.on ? "ON" : "OFF"
                        color: "#e9e9ec"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: deck.on ? I18n.t("Turn the equalizer off") : I18n.t("Turn the equalizer on")
            }
        }

        // ---- display: LED meter above each band ----
        Rectangle {
            id: display
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(90, deck.height * 0.24)
            radius: 6
            color: "#0c100d"
            border.color: "#050605"
            gradient: Gradient {
                GradientStop { position: 0; color: "#121812" }
                GradientStop { position: 1; color: "#070907" }
            }
            Row {
                anchors.centerIn: parent
                spacing: faders.columnGap
                Repeater {
                    model: 6
                    Column {
                        required property int index
                        readonly property real level: deck.levels[index] || 0
                        width: faders.columnWidth
                        spacing: 2
                        Repeater {
                            model: deck.segments
                            Rectangle {
                                required property int index
                                readonly property int step: deck.segments - 1 - index   // 0 = bottom
                                readonly property color lamp: step >= deck.segments - 2 ? "#ff5a4f"
                                                            : step >= deck.segments - 5 ? "#ffbf3c" : "#4be07c"
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.62
                                height: Math.max(2, (display.height - 24 - (deck.segments - 1) * 2) / deck.segments)
                                radius: 1
                                color: parent.level * deck.segments > step ? lamp : Qt.rgba(lamp.r, lamp.g, lamp.b, 0.1)
                            }
                        }
                    }
                }
            }
            // glass
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }

        // ---- faders ----
        Item {
            id: faders
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            readonly property real scaleW: 34
            readonly property real columnWidth: Math.min(64, (width - scaleW) / 6 - 8)
            readonly property real columnGap: ((width - scaleW) - 6 * columnWidth) / 6
            readonly property real railTop: 6
            readonly property real railBottom: height - 26
            readonly property real travel: railBottom - railTop

            // dB scale on the left
            Repeater {
                model: [["+12", 1], ["+6", 0.5], ["0", 0], ["-6", -0.5], ["-12", -1]]
                Engraved {
                    required property var modelData
                    x: 0
                    width: faders.scaleW - 6
                    horizontalAlignment: Text.AlignRight
                    y: faders.railTop + (1 - modelData[1]) / 2 * faders.travel - height / 2
                    text: modelData[0]
                    font.pixelSize: 10
                    opacity: 0.8
                }
            }

            Row {
                x: faders.scaleW + faders.columnGap / 2
                height: parent.height
                spacing: faders.columnGap
                Repeater {
                    model: 6
                    Item {
                        id: fader
                        required property int index
                        readonly property real gain: deck.bands[index] || 0
                        width: faders.columnWidth
                        height: faders.height
                        opacity: deck.on ? 1 : 0.55

                        // tick marks either side of the slot
                        Repeater {
                            model: 9
                            Rectangle {
                                required property int index
                                x: fader.width / 2 - 18
                                width: 36
                                height: 1
                                y: faders.railTop + index / 8 * faders.travel
                                color: index === 4 ? "#3c3f45" : Qt.rgba(0.24, 0.25, 0.27, 0.45)
                            }
                        }
                        Rectangle {  // slot
                            x: fader.width / 2 - 3
                            y: faders.railTop - 4
                            width: 6
                            height: faders.travel + 8
                            radius: 3
                            color: "#141416"
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                        }
                        Rectangle {  // chrome cap
                            id: cap
                            width: Math.min(fader.width - 8, 40)
                            height: 20
                            x: (fader.width - width) / 2
                            y: faders.railTop + (1 - fader.gain) / 2 * faders.travel - height / 2
                            radius: 3
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#fbfbfc" }
                                GradientStop { position: 0.5; color: "#c9ccd2" }
                                GradientStop { position: 1; color: "#8d9198" }
                            }
                            border.color: "#55585e"
                            Rectangle { anchors.centerIn: parent; width: parent.width - 8; height: 2; color: "#2b2d31" }
                        }
                        Engraved {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: faders.railBottom + 8
                            text: effects.bandLabels[fader.index] + "Hz"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            function set(my) {
                                effects.setBand(fader.index, 1 - 2 * (my - faders.railTop) / faders.travel)
                            }
                            onPressed: (mouse) => set(mouse.y)
                            onPositionChanged: (mouse) => { if (pressed) set(mouse.y) }
                            onDoubleClicked: effects.setBand(fader.index, 0)
                            onWheel: (wheel) => effects.setBand(fader.index, fader.gain + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0, 0, 0, 0.25) }

        // ---- tape speed and pitch lock ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Engraved { text: I18n.t("TAPE SPEED"); font.pixelSize: 11; font.letterSpacing: 1.6 }
            Item { Layout.fillWidth: true }
            Rectangle {  // little LCD with the speed
                implicitWidth: 64
                implicitHeight: 28
                radius: 4
                color: "#0c100d"
                border.color: "#050605"
                Label {
                    anchors.centerIn: parent
                    text: effects.tempo.toFixed(2) + "×"
                    color: "#7dffa6"
                    font.family: Theme.mono
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }
            AbstractButton {
                id: pitchLock
                implicitWidth: lockRow.implicitWidth + 22
                implicitHeight: 30
                onClicked: effects.setKeepPitch(!effects.keepPitch)
                background: Rectangle {
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0; color: pitchLock.down ? "#1a1a1d" : "#3a3a3f" }
                        GradientStop { position: 1; color: "#141416" }
                    }
                    border.color: "#0b0b0c"
                }
                contentItem: Row {
                    id: lockRow
                    spacing: 7
                    leftPadding: 11
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: effects.keepPitch ? "#ffbf3c" : "#4a3a1a"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("PITCH LOCK")
                        color: "#e9e9ec"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: effects.keepPitch ? I18n.t("Keep original pitch: on") : I18n.t("Speed also changes the key, just like sped-up or slowed-down songs.")
            }
        }
        // the speed fader gets the panel's whole width
        RowLayout {
            Layout.fillWidth: true
            Item {
                id: speed
                Layout.fillWidth: true
                implicitHeight: 30
                // 0.5x on the left, 2x on the right, 1x in the middle
                function pos(t) { return t <= 1 ? (t - 0.5) : 0.5 + (t - 1) / 2 }
                function tempoAt(p) { return p <= 0.5 ? 0.5 + p : 1 + (p - 0.5) * 2 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#141416"
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                }
                Rectangle {  // 1x mark
                    x: parent.width / 2 - 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 18
                    color: "#3c3f45"
                }
                Rectangle {
                    width: 20
                    height: 30
                    radius: 3
                    x: speed.pos(effects.tempo) * (speed.width - width)
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#fbfbfc" }
                        GradientStop { position: 0.5; color: "#c9ccd2" }
                        GradientStop { position: 1; color: "#8d9198" }
                    }
                    border.color: "#55585e"
                    Rectangle { anchors.centerIn: parent; width: 2; height: parent.height - 8; color: "#2b2d31" }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true
                    function set(mx) {
                        const p = Math.max(0, Math.min(1, (mx - 10) / Math.max(1, speed.width - 20)))
                        const t = speed.tempoAt(p)
                        effects.setTempo(Math.abs(t - 1) < 0.04 ? 1 : Math.round(t * 20) / 20)
                    }
                    onPressed: (mouse) => set(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) set(mouse.x) }
                    onDoubleClicked: effects.setTempo(1)
                }
            }
        }
    }
}
