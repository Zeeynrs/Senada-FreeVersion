import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

// The mini player ("dynamic island"): a pill at the top of the screen while the main window
// is minimized. It shows the song, how far along it is, play / pause and a button back to the
// full window; the arrow opens it wider, with the controls and the lyrics.
//
// Styles (Settings → Appearance → Mini player, session.islandStyle):
//   classic  black pill, the time, play / pause in a ring that fills up as the song plays
//   wave     black pill with sound bars in the song's colour (live with cava, else a rhythm)
//   lyrics   the sung line slides in under the title, a thin progress line along the bottom
//   glass    the album cover blurred behind the pill, lit with the song's colour
//
// Left alone for a few seconds (Settings: 5 to 15, or never), the island tucks into the top edge
// of the screen: it rises to the edge, its top corners go square and curve out into the edge
// like a notch, and it slims down to the cover, the title and sound bars. Pointing at it (or a
// new song) brings it back down.
//
// The window keeps one size and the pill animates inside it: a Wayland window cannot move
// itself to stay centred. Only the pill takes clicks (session.setInputArea), and on Hyprland
// the rules in senada/island.py, matched on the fixed title, float it at the top centre.
Window {
    id: island
    property bool expanded: false
    signal restore()

    readonly property var s: player.state
    readonly property bool hasTrack: !!s.hasTrack
    readonly property bool playing: hasTrack && s.isPlaying === true
    readonly property real progress: hasTrack && s.durationMs > 0 ? Math.min(1, player.position / s.durationMs) : 0
    readonly property color ink: Theme.accented ? Theme.accentInkOn(true) : "#ffffff"
    readonly property string style: session.islandStyle
    // the song's colour, bright enough to read on black
    readonly property color glow: Theme.mix(Theme.accent, Qt.rgba(1, 1, 1, 1), 0.25)
    readonly property string sungLine: lyrics.synced && lyrics.current >= 0 && lyrics.current < lyrics.lines.length
                                       ? (lyrics.lines[lyrics.current].text || "♪") : ""

    readonly property int margin: 12           // see-through room around the pill
    readonly property int compactW: 380
    readonly property int compactH: 60
    readonly property int wideW: 480           // senada/island.py SIZE = wideW/H + 2 * margin
    readonly property int wideH: 430
    readonly property int topGap: margin + 2   // between the floating island and the screen's top
    readonly property int dockedW: 380
    readonly property int dockedH: 52
    readonly property int ear: 14              // the inward curves where the docked island meets the edge
    readonly property int dockAfter: session.islandDock   // seconds; 0: it never docks
    property bool docked: false
    onExpandedChanged: if (expanded) docked = false
    onDockAfterChanged: if (dockAfter <= 0) docked = false

    title: "Senada mini player"
    width: wideW + 2 * margin
    height: wideH + 2 * margin
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    color: "transparent"
    // not owned by the main window (a Window declared inside another one is, by default):
    // Windows hides owned windows while their owner is minimized, which is exactly when the
    // mini player shows, and Main.qml then took that for a close and brought the window back
    transientParent: null
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
           | (Qt.platform.os === "windows" ? Qt.Tool : 0)   // no second taskbar button

    // top centre of the screen the main window is on (Wayland: the compositor decides)
    function place(onScreen) {
        if (Qt.platform.pluginName.indexOf("wayland") === 0) {
            session.prepareMiniPlayer()
            return
        }
        if (onScreen)
            screen = onScreen
        x = screen.virtualX + Math.round((screen.width - width) / 2)
        y = screen.virtualY   // the pill keeps its distance from the edge itself (topGap)
    }

    function updateInputArea() {
        if (visible)
            session.setInputArea(island, pill.x, pill.y, pill.width, pill.height)
    }
    onVisibleChanged: { updateInputArea(); if (!visible) docked = false }

    // ---- glass: the cover, blurred and cut to the pill's shape -------------------------------
    Item {
        id: glassArt
        visible: false
        x: pill.x; y: pill.y; width: pill.width; height: pill.height
        Image {
            anchors.fill: parent
            source: island.style === "glass" ? (island.s.image || island.s.imageSmall || "") : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(256, 256)
            asynchronous: true
        }
    }
    Rectangle {
        id: glassShape
        visible: false
        layer.enabled: true
        x: pill.x; y: pill.y; width: pill.width; height: pill.height
        radius: pill.radius
        topLeftRadius: pill.topLeftRadius
        topRightRadius: pill.topRightRadius
        color: "black"
    }
    MultiEffect {
        visible: island.style === "glass"
        x: pill.x; y: pill.y; width: pill.width; height: pill.height
        source: glassArt
        autoPaddingEnabled: false   // the blur stays inside the pill, so the mask lines up with it
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: 0.7
        brightness: -0.08
        maskEnabled: true
        maskSource: glassShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        id: pill
        objectName: "islandPill"
        x: Math.round((island.width - width) / 2)
        y: island.docked ? 0 : island.topGap
        width: island.expanded ? island.wideW : island.docked ? island.dockedW : island.compactW
        height: island.expanded ? island.wideH : island.docked ? island.dockedH : island.compactH
        radius: island.expanded ? 28 : island.docked ? island.dockedH / 2 : island.compactH / 2
        // docked: the top corners go square against the edge of the screen
        topLeftRadius: island.docked ? 0 : radius
        topRightRadius: island.docked ? 0 : radius
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on topLeftRadius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        // glass: a dark veil over the blurred cover, lit from the left with the song's colour
        color: island.style === "glass" ? "transparent" : "#0b0b0c"
        gradient: island.style === "glass" ? glassVeil : null
        border.width: island.docked ? 0 : 1
        border.color: island.style === "glass" ? Qt.rgba(1, 1, 1, 0.16)
                    : island.playing ? Theme.alpha(Theme.mix(Theme.accent, Qt.rgba(1, 1, 1, 1), 0.35), 0.35) : Qt.rgba(1, 1, 1, 0.09)
        antialiasing: true
        clip: true

        Gradient {
            id: glassVeil
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.alpha(Theme.mix(Theme.accent, Qt.rgba(0, 0, 0, 1), 0.3), 0.45) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.3) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
        }

        palette.windowText: "#f5f5f5"
        palette.text: "#f5f5f5"
        palette.buttonText: "#f5f5f5"
        palette.window: "#0b0b0c"
        palette.base: "#1c1c1c"
        palette.button: "#1c1c1c"

        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 600 } }
        onWidthChanged: island.updateInputArea()
        onHeightChanged: island.updateInputArea()
        onXChanged: island.updateInputArea()
        onYChanged: island.updateInputArea()

        // pointing at the docked island brings it back down; leaving it starts the wait again
        HoverHandler {
            id: pillHover
            onHoveredChanged: if (hovered) island.docked = false
        }

        // ---- the always-visible row ------------------------------------------------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: island.docked ? island.dockedH : island.compactH

            // drag to move it, double-click to open Senada again
            DragHandler {
                target: null
                onActiveChanged: if (active) island.startSystemMove()
            }
            TapHandler { onDoubleTapped: island.restore() }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Cover {
                    Layout.preferredWidth: island.docked ? 36 : 40
                    Layout.preferredHeight: island.docked ? 36 : 40
                    radius: island.expanded ? 10 : island.docked ? 9 : 20
                    Behavior on radius { NumberAnimation { duration: 300 } }
                    source: island.s.imageSmall || island.s.image || ""
                    fallbackIcon: "music"
                }

                // title and artist (lyrics: the title, then the sung line)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 40
                    spacing: 1
                    readonly property bool ticker: island.style === "lyrics" && island.hasTrack && island.sungLine !== ""
                    Label {
                        Layout.fillWidth: true
                        text: island.hasTrack ? island.s.name : I18n.t("Nothing playing yet")
                        elide: Text.ElideRight
                        color: parent.ticker ? Qt.rgba(1, 1, 1, 0.6) : "#ffffff"
                        font.pixelSize: parent.ticker ? 11 : (island.docked ? 14 : 13)
                        font.weight: parent.ticker ? Font.Normal : Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: island.hasTrack && !parent.ticker && !island.docked
                        text: island.s.artists || ""
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                    }
                    Ticker {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        visible: parent.ticker
                        text: island.sungLine
                    }
                }

                Label {
                    visible: island.hasTrack && !island.expanded && !island.docked && (island.style === "classic" || island.style === "glass")
                    text: Theme.fmt(player.position) + " / " + Theme.fmt(island.s.durationMs)
                    color: Qt.rgba(1, 1, 1, island.style === "glass" ? 0.75 : 0.6)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }

                SoundBars {
                    // the wave style, and every style while docked
                    visible: (island.style === "wave" || island.docked) && island.hasTrack && !island.expanded
                    Layout.preferredWidth: island.docked ? 32 : 34
                    Layout.preferredHeight: island.docked ? 20 : 22
                    running: visible && island.visible
                    playing: island.playing
                    color: island.glow
                }

                // play / pause inside a ring that fills up as the song plays
                AbstractButton {
                    id: playButton
                    visible: !island.expanded && !island.docked
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    enabled: island.hasTrack || player.queue.length > 0
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    onClicked: player.togglePlay()
                    background: Rectangle {
                        radius: width / 2
                        color: playButton.down ? Qt.rgba(1, 1, 1, 0.16) : playButton.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    }
                    contentItem: Item {
                        Shape {
                            anchors.fill: parent
                            visible: island.style !== "lyrics"   // that style draws the progress along the bottom
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.14)
                                strokeWidth: 2.5
                                fillColor: "transparent"
                                PathAngleArc { centerX: 19; centerY: 19; radiusX: 17; radiusY: 17; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: island.style === "wave" ? island.glow : island.ink
                                strokeWidth: 2.5
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 19; centerY: 19; radiusX: 17; radiusY: 17
                                    startAngle: -90
                                    sweepAngle: 360 * island.progress
                                }
                            }
                        }
                        Icon {
                            anchors.centerIn: parent
                            glyph: island.playing ? "pause" : "play"
                            size: 18
                            color: "#ffffff"
                        }
                    }
                }

                IconButton {
                    objectName: "islandChevron"
                    visible: !island.docked
                    iconName: "chevron-down"
                    size: 20
                    tint: Qt.rgba(1, 1, 1, 0.8)
                    rotation: island.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    onClicked: island.expanded = !island.expanded
                }
                IconButton {
                    iconName: "open-app"
                    visible: !island.docked
                    size: 17
                    tint: Qt.rgba(1, 1, 1, 0.8)
                    onClicked: island.restore()
                }
            }

            // lyrics: how far the song is, a thin line along the bottom of the pill
            Rectangle {
                visible: island.style === "lyrics" && island.hasTrack && !island.expanded && !island.docked
                x: island.compactH / 2
                y: parent.height - 5
                width: parent.width - island.compactH
                height: 2
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    width: parent.width * island.progress
                    height: parent.height
                    radius: 1
                    color: island.glow
                }
            }
        }

        // ---- opened wider: seek bar, controls, lyrics ------------------------------------
        ColumnLayout {
            objectName: "islandBody"
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 2
            anchors.bottomMargin: 8
            spacing: 4
            opacity: island.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: island.expanded ? 320 : 120 } }

            SeekBar {
                Layout.fillWidth: true
                fontSize: 11
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "previous"; size: 22
                    onClicked: player.previous()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: island.playing ? "pause" : "play"
                    size: 22
                    filled: true
                    enabled: island.hasTrack || player.queue.length > 0
                    onClicked: player.togglePlay()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "next"; size: 22
                    onClicked: player.next()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4

                // lines fade out at the edges instead of being cut (a mask, so it works on
                // the black pill and on the glass alike)
                Item {
                    id: lyricsBox
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: lyricsFade
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    LyricsView {
                        id: islandLyrics
                        anchors.fill: parent
                        textSize: 17
                        lineGap: 8
                        followHeight: true   // the lyrics open at the sung line as the pill grows
                        showSource: false
                    }
                }
                Rectangle {
                    id: lyricsFade
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: Math.min(0.45, 28 / Math.max(1, lyricsFade.height)); color: "black" }
                        GradientStop { position: Math.max(0.55, 1 - 36 / Math.max(1, lyricsFade.height)); color: "black" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }

    // ---- lyrics: the sung line slides up and the next one comes in from below -----------------
    component Ticker: Item {
        id: tk
        property string text
        clip: true
        onTextChanged: {
            slide.complete()
            outgoing.text = incoming.text
            incoming.text = tk.text
            slide.start()
        }
        Label {
            id: outgoing
            width: parent.width
            elide: Text.ElideRight
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Label {
            id: incoming
            width: parent.width
            elide: Text.ElideRight
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Component.onCompleted: text = tk.text
        }
        ParallelAnimation {
            id: slide
            NumberAnimation { target: outgoing; property: "y"; from: 0; to: -tk.height; duration: 320; easing.type: Easing.InCubic }
            NumberAnimation { target: outgoing; property: "opacity"; from: 1; to: 0; duration: 260 }
            NumberAnimation { target: incoming; property: "y"; from: tk.height; to: 0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: incoming; property: "opacity"; from: 0; to: 1; duration: 380 }
        }
    }

    // ---- wave: bars that move with the music --------------------------------------------------
    // From cava when it runs (visualizer.active, see AppShell.qml); without it, a calm rhythm
    // that only moves while the song plays.
    component SoundBars: Item {
        id: sb
        property bool running: false
        property bool playing: false
        property color color: "white"
        readonly property int count: 5
        property var levels: [0.2, 0.2, 0.2, 0.2, 0.2]
        property var targets: [0.2, 0.2, 0.2, 0.2, 0.2]
        property real clock: 0
        FrameAnimation {
            running: sb.running && (sb.playing || sb.levels.some(v => v > 0.16))
            onTriggered: {
                const dt = Math.min(0.05, frameTime)
                sb.clock += dt
                const live = visualizer && visualizer.active ? (visualizer.bars || []) : []
                const next = sb.levels.slice()
                const targets = sb.targets.slice()
                for (let i = 0; i < sb.count; i++) {
                    let goal
                    if (!sb.playing) {
                        goal = 0.15
                    } else if (live.length > 0) {
                        // a band of the spectrum per bar, low on the left
                        const from = Math.floor(i * live.length / sb.count)
                        const to = Math.max(from + 1, Math.floor((i + 1) * live.length / sb.count))
                        let peak = 0
                        for (let j = from; j < to; j++) peak = Math.max(peak, live[j] || 0)
                        goal = 0.15 + 0.85 * Math.min(1, peak * 1.4)
                    } else {
                        // a new random height for a bar every so often, each at its own pace
                        if (Math.random() < dt * (3 + i))
                            targets[i] = 0.25 + Math.random() * 0.75
                        goal = targets[i]
                    }
                    next[i] += (goal - next[i]) * Math.min(1, dt * 14)
                }
                sb.targets = targets
                sb.levels = next
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: sb.count
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: Math.max(4, sb.height * sb.levels[index])
                    radius: 2
                    color: sb.color
                }
            }
        }
    }

    // ---- tucking into the top edge -------------------------------------------------------------
    Timer {
        interval: Math.max(1, island.dockAfter) * 1000
        running: island.visible && island.dockAfter > 0 && island.hasTrack && !island.docked
                 && !island.expanded && !pillHover.hovered
        onTriggered: island.docked = true
    }
    // a new song shows itself before the island tucks away again
    Connections {
        target: player
        function onTrackChanged() { island.docked = false }
    }
    // the inward curves on either side, where the island flows into the edge of the screen
    readonly property color earColor: style === "glass" ? Qt.rgba(0, 0, 0, 0.62) : "#0b0b0c"
    Shape {
        x: pill.x - island.ear
        y: pill.y
        width: island.ear
        height: island.ear
        opacity: island.docked ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: island.earColor
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: island.ear; y: 0 }
            PathLine { x: island.ear; y: island.ear }
            PathArc { x: 0; y: 0; radiusX: island.ear; radiusY: island.ear; direction: PathArc.Counterclockwise }
        }
    }
    Shape {
        x: pill.x + pill.width
        y: pill.y
        width: island.ear
        height: island.ear
        opacity: island.docked ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: island.earColor
            strokeColor: "transparent"
            startX: island.ear; startY: 0
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: island.ear }
            PathArc { x: island.ear; y: 0; radiusX: island.ear; radiusY: island.ear; direction: PathArc.Clockwise }
        }
    }

    Shortcut { sequence: "Space"; onActivated: player.togglePlay() }
}
