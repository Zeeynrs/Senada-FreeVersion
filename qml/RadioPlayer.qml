import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as an old valve radio (Settings → Appearance → Full view style): a wooden cabinet
// with a cloth speaker grille, a warm glowing dial whose red needle moves along the FM scale
// as the song plays (and shows the sung lyric line), a volume and a tuning knob, and a green
// "magic eye" lamp that opens and closes with the music. The queue becomes the radio's preset
// stations and the equalizer a panel of tone knobs. Controls sit in a strip along the bottom.
Item {
    id: rp
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

    readonly property color glow: "#ffcf73"
    readonly property color brass: "#d9b26a"
    readonly property color cream: "#f3e2c0"

    // the lyrics show in the dial, so only the queue and the equalizer need room beside it
    readonly property bool sideOpen: showPanel && panel !== "lyrics"
    readonly property real stageW: sideOpen ? width * 0.56 : width
    readonly property real radioW: Math.max(320, Math.min(stageW * 0.86, areaH * 0.92 / 0.6, 1040))

    // how loud it is right now, for the magic eye (a gentle stand-in without cava)
    property real level: 0
    property real clock: 0
    FrameAnimation {
        running: rp.active && rp.s.isPlaying && rp.Window.active
        onTriggered: {
            rp.clock += frameTime
            const raw = visualizer ? (visualizer.bars || []) : []
            let v = 0
            if (visualizer && visualizer.active && raw.length) {
                for (let i = 0; i < Math.min(8, raw.length); i++) v += raw[i] || 0
                v /= Math.min(8, raw.length)
            } else {
                v = 0.5 + 0.3 * Math.sin(rp.clock * 3.1) * Math.sin(rp.clock * 1.7)
            }
            rp.level += (Math.max(0, Math.min(1, v)) - rp.level) * Math.min(1, frameTime * 8)
        }
    }

    // ---- the radio ---------------------------------------------------------------------------
    Item {
        id: radio
        readonly property real u: width / 100           // in hundredths of the radio's width
        width: rp.radioW
        height: width * 0.6
        x: (rp.stageW - width) / 2 + (rp.sideOpen ? 24 : 0)
        y: rp.topSpace + (rp.areaH - height) / 2
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        // shadow and feet
        Rectangle {
            id: radioShape
            anchors.fill: parent
            radius: 5 * radio.u
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: radioShape
            source: radioShape
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.7
            shadowBlur: 1.0
            shadowVerticalOffset: 18
        }
        Repeater {
            model: [12, 80]
            Rectangle {
                required property var modelData
                x: modelData * radio.u
                y: radio.height - 2 * radio.u
                width: 8 * radio.u
                height: 4 * radio.u
                radius: radio.u
                color: "#1d120b"
            }
        }

        // wooden cabinet
        Rectangle {
            anchors.fill: parent
            radius: 5 * radio.u
            gradient: Gradient {
                GradientStop { position: 0; color: "#7a4a29" }
                GradientStop { position: 0.55; color: "#5e3720" }
                GradientStop { position: 1; color: "#3f2414" }
            }
            border.color: "#2a170c"
            border.width: Math.max(1, 0.4 * radio.u)
        }
        Canvas {  // wood grain
            anchors.fill: parent
            anchors.margins: radio.u
            opacity: 0.35
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#2a160a"
                ctx.lineWidth = 1
                for (let i = 0; i < 26; i++) {
                    const y0 = (i + 0.5) * height / 26
                    ctx.beginPath()
                    for (let x = 0; x <= width; x += 8) {
                        const y = y0 + 3 * Math.sin(x / 60 + i * 1.3) + 2 * Math.sin(x / 23 + i)
                        if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
        }
        Rectangle {  // inner frame
            x: 2.5 * radio.u; y: 2.5 * radio.u
            width: radio.width - 5 * radio.u
            height: radio.height - 5 * radio.u
            radius: 3.5 * radio.u
            color: "transparent"
            border.color: Qt.rgba(1, 0.85, 0.6, 0.18)
            border.width: Math.max(1, 0.4 * radio.u)
        }

        // ---- speaker grille: cloth behind wooden slats ----
        Item {
            id: grille
            x: 6 * radio.u
            y: 6 * radio.u
            width: 44 * radio.u
            height: radio.height - 12 * radio.u
            Rectangle {
                anchors.fill: parent
                radius: 2.5 * radio.u
                color: "#cdb98f"
                border.color: "#2a170c"
                border.width: Math.max(1, 0.4 * radio.u)
            }
            Canvas {  // weave
                anchors.fill: parent
                anchors.margins: 2
                opacity: 0.35
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#6b5530"
                    ctx.lineWidth = 1
                    for (let x = 0; x < width; x += 3) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
                    ctx.strokeStyle = "#8a7246"
                    for (let y = 0; y < height; y += 3) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
                }
            }
            // the cloth trembles a little with the music
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (0.5 + 0.08 * rp.level)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(0.25, 0.17, 0.08, 0.18 + 0.2 * rp.level)
                border.width: Math.max(2, radio.u)
            }
            Repeater {  // slats
                model: 5
                Rectangle {
                    required property int index
                    x: (index + 1) * grille.width / 6 - width / 2
                    y: 0
                    width: 2.2 * radio.u
                    height: grille.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#4a2a16" }
                        GradientStop { position: 0.5; color: "#7a4a29" }
                        GradientStop { position: 1; color: "#3f2414" }
                    }
                }
            }
            Rectangle {  // brass badge
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - 4 * radio.u
                width: 20 * radio.u
                height: 5 * radio.u
                radius: 1.2 * radio.u
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f0d08a" }
                    GradientStop { position: 1; color: "#a8823d" }
                }
                border.color: "#6e5222"
                Label {
                    anchors.centerIn: parent
                    text: "SENADA"
                    color: "#4a3412"
                    font.pixelSize: 2.6 * radio.u
                    font.weight: Font.Black
                    font.letterSpacing: 0.6 * radio.u
                }
            }
        }

        // ---- the dial ----
        Item {
            id: dial
            x: 54 * radio.u
            y: 6 * radio.u
            width: 40 * radio.u
            height: 26 * radio.u
            Rectangle {  // warm light around the glass
                anchors.centerIn: parent
                width: parent.width + 3 * radio.u
                height: parent.height + 3 * radio.u
                radius: 3 * radio.u
                color: Qt.rgba(1, 0.75, 0.3, rp.s.isPlaying ? 0.22 : 0.1)
                Behavior on color { ColorAnimation { duration: 600 } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 2 * radio.u
                border.color: "#2a170c"
                border.width: Math.max(1, 0.5 * radio.u)
                gradient: Gradient {
                    GradientStop { position: 0; color: rp.s.isPlaying ? "#ffe2a3" : "#d8c39a" }
                    GradientStop { position: 1; color: rp.s.isPlaying ? "#e9a443" : "#b48b4f" }
                }
            }
            // what is playing: the sung line, else the song
            Column {
                x: 2.5 * radio.u
                y: 1.8 * radio.u
                width: dial.width - 9 * radio.u
                spacing: 0.4 * radio.u
                readonly property var lines: lyrics.status === "ready" ? lyrics.lines : []
                readonly property int at: lyrics.synced ? lyrics.current : -1
                readonly property bool sing: lines.length > 0 && at >= 0 && rp.panel === "lyrics" && rp.showPanel
                Label {
                    width: parent.width
                    text: parent.sing ? (parent.lines[parent.at].text || "♪") : (rp.s.name || I18n.t("Nothing is playing"))
                    color: "#3a2208"
                    font.family: "Georgia"
                    font.pixelSize: 3.0 * radio.u
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width
                    text: parent.sing ? (parent.at + 1 < parent.lines.length ? parent.lines[parent.at + 1].text : "")
                                      : (rp.s.artists || "")
                    color: Qt.rgba(0.23, 0.13, 0.03, 0.6)
                    font.family: "Georgia"
                    font.pixelSize: 2.4 * radio.u
                    font.italic: true
                    elide: Text.ElideRight
                }
            }
            // FM scale along the bottom of the glass
            Item {
                id: fmScale
                x: 3 * radio.u
                width: dial.width - 6 * radio.u
                y: dial.height - 9 * radio.u
                height: 7 * radio.u
                Repeater {
                    model: 41
                    Rectangle {
                        required property int index
                        x: index / 40 * fmScale.width - width / 2
                        y: index % 5 === 0 ? 0 : 1.2 * radio.u
                        width: Math.max(1, 0.25 * radio.u)
                        height: index % 5 === 0 ? 2.6 * radio.u : 1.4 * radio.u
                        color: "#4a2a0e"
                    }
                }
                Repeater {
                    model: [88, 92, 96, 100, 104, 108]
                    Label {
                        required property var modelData
                        required property int index
                        x: index / 5 * fmScale.width - width / 2
                        y: 3 * radio.u
                        text: modelData
                        color: "#4a2a0e"
                        font.pixelSize: 2.2 * radio.u
                        font.weight: Font.Bold
                    }
                }
                Label {  // band, in the top corner of the glass
                    anchors.right: parent.right
                    y: -fmScale.y + 1.6 * radio.u
                    text: "FM
MHz"
                    horizontalAlignment: Text.AlignRight
                    color: Qt.rgba(0.29, 0.16, 0.05, 0.7)
                    font.pixelSize: 1.8 * radio.u
                    font.weight: Font.Bold
                    font.letterSpacing: 0.3 * radio.u
                }
            }
            Rectangle {  // the needle, moving along the scale with the song
                x: fmScale.x + rp.progress * fmScale.width - width / 2
                y: fmScale.y - 2.5 * radio.u
                width: Math.max(2, 0.45 * radio.u)
                height: fmScale.height + 3.5 * radio.u
                color: "#c4271b"
                opacity: 0.9
            }
            Rectangle {  // glass glare
                anchors.fill: parent
                radius: 2 * radio.u
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
            TapHandler {  // click the scale to tune: seek there
                onTapped: (point) => {
                    if (!rp.s.hasTrack) return
                    const f = (point.position.x - fmScale.x) / fmScale.width
                    player.seek(Math.max(0, Math.min(1, f)) * rp.durationMs)
                }
            }
            HoverHandler { cursorShape: rp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }

        // ---- knobs and the magic eye under the dial ----
        RotaryKnob {
            x: 56 * radio.u
            y: 37 * radio.u
            width: 14 * radio.u
            height: width + 34
            from: 0; to: 100; resetValue: 80; stepSize: 5
            value: rp.volume
            label: I18n.t("VOLUME")
            valueText: rp.volume + "%"
            labelColor: rp.cream
            onMoved: (v) => player.setVolume(Math.round(v))
        }
        RotaryKnob {
            x: 78 * radio.u
            y: 37 * radio.u
            width: 14 * radio.u
            height: width + 34
            from: 0; to: rp.durationMs; resetValue: 0; stepSize: 5000
            value: player ? player.position : 0
            interactive: !!rp.s.hasTrack
            label: I18n.t("TUNING")
            valueText: Theme.fmt(player ? player.position : 0)
            labelColor: rp.cream
            onMoved: (v) => player.seek(v)
        }
        Item {  // magic eye: a green lamp whose dark wedge closes when the music is loud
            id: eye
            x: 72.2 * radio.u
            y: 40 * radio.u
            width: 4.6 * radio.u
            height: width
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#1b2a1e"; border.color: "#0d140f" }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: width
                radius: width / 2
                color: rp.s.isPlaying ? "#47e486" : "#24603d"
                opacity: 0.6 + 0.4 * rp.level
            }
            Canvas {
                anchors.fill: parent
                property real open: rp.s.isPlaying ? 1 - rp.level : 1
                onOpenChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = width * 0.41, c = width / 2, a = 0.15 + 0.85 * open
                    ctx.fillStyle = "#13261a"
                    ctx.beginPath()
                    ctx.moveTo(c, c)
                    ctx.arc(c, c, r, -Math.PI / 2 - a, -Math.PI / 2 + a)
                    ctx.closePath()
                    ctx.fill()
                }
            }
            Rectangle {  // glow
                anchors.centerIn: parent
                width: parent.width * 2
                height: width
                radius: width / 2
                color: Qt.rgba(0.28, 0.9, 0.52, 0.12 * rp.level)
                visible: rp.s.isPlaying
            }
        }
    }

    // ---- beside the radio: preset stations (queue) or tone knobs (equalizer) ----------------------
    // a wooden frame around a warm glass panel
    component WoodPanel: Item {
        id: wp
        property string title
        default property alias content: inner.data
        Rectangle {
            id: frameShape
            anchors.fill: parent
            radius: 14
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: frameShape
            source: frameShape
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.9
            shadowVerticalOffset: 12
        }
        Rectangle {
            anchors.fill: parent
            radius: 14
            gradient: Gradient {
                GradientStop { position: 0; color: "#7a4a29" }
                GradientStop { position: 1; color: "#43271a" }
            }
            border.color: "#2a170c"
        }
        Rectangle {
            id: glass
            anchors.fill: parent
            anchors.margins: 14
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a2412" }
                GradientStop { position: 1; color: "#221409" }
            }
            border.color: "#1a0e06"
        }
        Label {
            x: glass.x + 18
            y: glass.y + 14
            text: wp.title
            color: "#ffcf73"
            font.family: "Georgia"
            font.pixelSize: 20
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        Item {
            id: inner
            x: glass.x + 12
            y: glass.y + 52
            width: glass.width - 24
            height: glass.height - 64
        }
    }
    readonly property rect sideRect: Qt.rect(width * 0.6, topSpace + 6, width * 0.4 - 48, areaH - 12)

    WoodPanel {
        x: rp.sideRect.x; y: rp.sideRect.y; width: rp.sideRect.width; height: rp.sideRect.height
        visible: opacity > 0
        opacity: rp.sideOpen && rp.panel === "queue" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        title: I18n.t("Preset stations")

        ListView {
            id: stations
            anchors.fill: parent
            clip: true
            model: player.queue
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: NScrollBar {}
            SmoothScroll { flickable: stations }
            Component.onCompleted: player.refreshQueue()
            delegate: Item {
                id: station
                required property var modelData
                required property int index
                width: stations.width
                height: 50
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(1, 0.81, 0.45, stationHover.hovered ? 0.14 : 0.05)
                }
                Rectangle {  // brass preset button with its number
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 17
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#f0d08a" }
                        GradientStop { position: 1; color: "#a8823d" }
                    }
                    border.color: "#6e5222"
                    Label {
                        anchors.centerIn: parent
                        text: station.index + 1
                        color: "#3a2208"
                        font.pixelSize: 14
                        font.weight: Font.Black
                    }
                }
                Column {
                    x: 56
                    width: parent.width - 56 - 60
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: station.modelData.name || ""
                        color: "#ffcf73"
                        font.family: "Georgia"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: station.modelData.artists || ""
                        color: Qt.rgba(1, 0.81, 0.45, 0.6)
                        font.family: "Georgia"
                        font.pixelSize: 13
                        font.italic: true
                        elide: Text.ElideRight
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: station.modelData.durationMs ? Theme.fmt(station.modelData.durationMs) : ""
                    color: Qt.rgba(1, 0.81, 0.45, 0.55)
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
                HoverHandler { id: stationHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: player.skip(station.index + 1) }
            }
            Label {
                anchors.centerIn: parent
                visible: stations.count === 0
                text: I18n.t("The queue is empty")
                color: Qt.rgba(1, 0.81, 0.45, 0.6)
                font.family: "Georgia"
                font.pixelSize: 16
            }
        }
    }

    WoodPanel {
        x: rp.sideRect.x; y: rp.sideRect.y; width: rp.sideRect.width; height: rp.sideRect.height
        visible: opacity > 0
        opacity: rp.sideOpen && rp.panel === "equalizer" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        title: I18n.t("Tone control")

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                // preset and power as brass push buttons
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        implicitWidth: btnText.implicitWidth + 24
                        implicitHeight: 30
                        radius: 15
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#f0d08a" }
                            GradientStop { position: 1; color: "#a8823d" }
                        }
                        border.color: "#6e5222"
                        opacity: index === 1 && !effects.enabled ? 0.6 : 1
                        Label {
                            id: btnText
                            anchors.centerIn: parent
                            text: index === 0 ? I18n.t(effects.preset) + "  ↻" : (effects.enabled ? "ON" : "OFF")
                            color: "#3a2208"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: index === 0 ? effects.nextPreset() : effects.setEnabled(!effects.enabled) }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: 4
                columnSpacing: 4
                Repeater {
                    model: 6
                    RotaryKnob {
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumHeight: 150
                        opacity: effects.enabled ? 1 : 0.55
                        value: effects.bands[index] || 0
                        label: effects.bandLabels[index] + " Hz"
                        valueText: ((effects.bands[index] || 0) >= 0 ? "+" : "") + ((effects.bands[index] || 0) * 12).toFixed(1) + " dB"
                        labelColor: rp.glow
                        onMoved: (v) => effects.setBand(index, v)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                RotaryKnob {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 120
                    from: 0.5; to: 2.0; resetValue: 1.0; stepSize: 0.05
                    value: effects.tempo
                    label: I18n.t("TEMPO")
                    valueText: effects.tempo.toFixed(2) + "×"
                    labelColor: rp.glow
                    onMoved: (v) => effects.setTempo(Math.abs(v - 1) < 0.04 ? 1 : Math.round(v * 20) / 20)
                }
                // a bat-handle toggle switch for the pitch lock
                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6
                    Item {
                        width: 40
                        height: 56
                        Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15; color: "#c9ccd2"; border.color: "#55585e" }
                        Rectangle {
                            x: parent.width / 2 - width / 2
                            y: effects.keepPitch ? 2 : parent.height / 2
                            width: 8
                            height: parent.height / 2 - 2
                            radius: 4
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#ffffff" }
                                GradientStop { position: 1; color: "#8d9198" }
                            }
                            Behavior on y { NumberAnimation { duration: 140 } }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: effects.setKeepPitch(!effects.keepPitch) }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("PITCH LOCK")
                        color: rp.glow
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: rp.bottomSpace
        onCloseRequested: rp.closeRequested()
    }
}
