import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full-window "now playing": round cover inside a circular visualizer (bars & wave),
// seek and volume bars, synced lyrics, queue and equalizer, on the blurred cover art.
Item {
    id: im
    objectName: "immersive"
    property bool open: false
    property string panel: "lyrics"  // "lyrics" | "queue" | "equalizer"
    readonly property var s: player ? player.state : ({})
    readonly property bool wide: width > 900
    property bool panelOpen: true
    readonly property bool showPanel: panelOpen
    readonly property bool shown: y < height
    signal close()

    function selectPanel(name) {
        if (panelOpen && panel === name) {
            panelOpen = false
        } else {
            panel = name
            panelOpen = true
        }
    }

    function toggleVisualizerStyle() {
        if (!session) return
        session.visualizerStyle = (session.visualizerStyle === "wave") ? "bars" : "wave"
    }

    // always dark (it sits on the blurred cover art), whatever the app theme is
    palette.windowText: "#f5f5f5"
    palette.text: "#f5f5f5"
    palette.buttonText: "#f5f5f5"
    palette.window: "#0b0b0b"
    palette.base: "#1c1c1c"
    palette.button: "#1c1c1c"
    palette.placeholderText: "#8a8a8a"

    y: open ? 0 : height
    visible: shown
    Behavior on y { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }

    // swallow input so nothing underneath reacts
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

    Rectangle { anchors.fill: parent; color: "#14161b" }

    Image {
        id: bgArt
        anchors.fill: parent
        source: im.s.image || ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bgArt
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.6
        brightness: -0.25
        opacity: bgArt.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
        SequentialAnimation on scale {
            running: im.shown
            loops: Animation.Infinite
            NumberAnimation { from: 1.15; to: 1.32; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.32; to: 1.15; duration: 24000; easing.type: Easing.InOutSine }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.07, 0.09, 0.28) }
            GradientStop { position: 0.6; color: Qt.rgba(0.06, 0.07, 0.09, 0.42) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.07, 0.09, 0.68) }
        }
    }

    // ========================================================================
    // TOP BAR: Round Close Button (Left) & Segmented Pill Toolbar (Right)
    // ========================================================================
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68

        // Top-left circular close button ("×")
        Rectangle {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 140 } }

            Icon {
                anchors.centerIn: parent
                glyph: "close"
                size: 15
                color: "#ffffff"
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: im.close()
            }
        }

        // Top-right translucent pill toolbar
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            width: pillRow.implicitWidth + 12
            radius: 20
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 4

                // 1. Cover-only view toggle
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: !im.showPanel
                    color: active ? "#ffffff" : (covMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Canvas {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        property color pen: parent.active ? "#181a20" : "#ffffff"
                        onPenChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = pen
                            ctx.lineWidth = 1.6
                            ctx.lineJoin = "round"
                            ctx.strokeRect(2, 2, 12, 12)
                            ctx.beginPath()
                            ctx.moveTo(2.5, 11.5)
                            ctx.lineTo(6.5, 7.5)
                            ctx.lineTo(9.5, 10.5)
                            ctx.lineTo(11.5, 8.5)
                            ctx.lineTo(13.5, 11.5)
                            ctx.stroke()
                        }
                    }
                    MouseArea {
                        id: covMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.panelOpen = !im.panelOpen
                    }
                }

                // 2. Lyrics tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "lyrics"
                    color: active ? "#ffffff" : (lyrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "lyrics"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: lyrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("lyrics")
                    }
                }

                // 3. Queue tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "queue"
                    color: active ? "#ffffff" : (qMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "queue"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: qMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("queue")
                    }
                }

                // 4. Visualizer Style Toggle (Moon icon: switches "bars" <-> "wave")
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool isWave: session && session.visualizerStyle === "wave"
                    color: styleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Canvas {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        property bool waveMode: parent.isWave
                        onWaveModeChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#ffffff"
                            ctx.lineWidth = 1.6
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            // Crescent moon icon matching the screenshots
                            ctx.beginPath()
                            ctx.arc(8.5, 8, 5.5, 0.45, Math.PI * 1.55)
                            ctx.quadraticCurveTo(6.0, 8.0, 12.8, 11.4)
                            ctx.closePath()
                            if (waveMode) {
                                ctx.fillStyle = "rgba(255, 255, 255, 0.35)"
                                ctx.fill()
                            }
                            ctx.stroke()
                        }
                    }
                    MouseArea {
                        id: styleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.toggleVisualizerStyle()
                    }
                    ToolTip.visible: styleMouse.containsMouse
                    ToolTip.text: (session && session.visualizerStyle === "wave")
                                  ? I18n.t("Visualizer style: wave (click for bars)")
                                  : I18n.t("Visualizer style: bars (click for wave)")
                    ToolTip.delay: 400
                }

                // 5. Equalizer tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "equalizer"
                    color: active ? "#ffffff" : (eqMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "equalizer"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: eqMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("equalizer")
                    }
                }
            }
        }
    }

    // ========================================================================
    // MAIN CONTENT: Left (cover & controls) + Right (panel)
    // ========================================================================
    RowLayout {
        id: mainRow
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        anchors.bottomMargin: 36
        width: Math.min(parent.width - 96, im.wide && im.showPanel ? 1100 : 680)
        spacing: im.wide && im.showPanel ? Math.min(72, Math.max(40, parent.width * 0.04)) : 32

        // ---- LEFT COLUMN: cover + visualizer, track info and controls ----
        ColumnLayout {
            visible: im.wide || !im.showPanel
            Layout.preferredWidth: im.wide && im.showPanel ? Math.min(420, mainRow.width * 0.40) : -1
            Layout.fillWidth: !im.wide || !im.showPanel
            Layout.fillHeight: true
            spacing: 12

            Item { Layout.fillHeight: true }

            // Round cover inside the visualizer
            Item {
                id: coverStage
                readonly property real side: Math.max(220, Math.min(
                    im.wide && im.showPanel ? Math.min(390, im.width * 0.36) : Math.min(420, im.width - 120),
                    im.height - 350,
                    390
                ))
                readonly property bool visOn: session ? session.visualizerEnabled : true
                readonly property real coverSide: Math.round(side * 0.62)
                Layout.preferredWidth: side
                Layout.preferredHeight: side
                Layout.alignment: Qt.AlignHCenter

                CircularSpectrum {
                    anchors.fill: parent
                    visible: coverStage.visOn
                    active: visualizer ? visualizer.active : false
                    playing: !!im.s.isPlaying && im.shown
                    style: session ? session.visualizerStyle : "bars"
                    accentColor: Theme.accent
                    coverRadius: (bigCover.width * bigCover.scale) / 2
                }

                Cover {
                    id: bigCover
                    anchors.centerIn: parent
                    width: coverStage.coverSide
                    height: coverStage.coverSide
                    round: true
                    source: im.s.imageLarge || im.s.image || ""
                    scale: im.s.isPlaying ? 1.0 : 0.95
                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                }
            }

            // Centered Track Title, Artist + "•••", Album Name
            ColumnLayout {
                Layout.preferredWidth: Math.min(400, coverStage.side + 40)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: im.s.name || I18n.t("Nothing is playing")
                    font.pixelSize: 26
                    font.weight: Font.Black
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    LinkLabel {
                        text: im.s.artists || ""
                        font.pixelSize: 16
                        color: Qt.rgba(1, 1, 1, 0.72)
                        onClicked: if (im.s.artistId) { im.close(); Nav.go("artist", im.s.artistId) }
                    }
                    IconButton {
                        visible: !!im.s.hasTrack
                        implicitWidth: 30
                        iconName: im.s.liked ? "heart" : "heart-outline"
                        size: 17
                        tint: im.s.liked ? Theme.like : Qt.rgba(1, 1, 1, 0.7)
                        tip: im.s.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                        onClicked: player.toggleLike()
                    }
                }

                Label {
                    visible: !!(im.s.album)
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: im.s.album || ""
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.45)
                    elide: Text.ElideRight
                    HoverHandler { cursorShape: im.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (im.s.albumId) { im.close(); Nav.go("album", im.s.albumId) } }
                }
            }

            // Seek bar with elapsed and "-remaining" time
            RowLayout {
                id: seekRow
                Layout.preferredWidth: Math.min(360, coverStage.side + 20)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                spacing: 10

                readonly property real durationMs: Math.max(1, im.s.durationMs || 0)
                readonly property real currentMs: seekMouse.pressed ? seekMouse.dragMs : (player ? player.position : 0)
                readonly property real progress: Math.max(0, Math.min(1, currentMs / durationMs))

                Label {
                    text: Theme.fmt(seekRow.currentMs)
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    id: seekTrack
                    Layout.fillWidth: true
                    height: 22
                    readonly property bool engaged: seekMouse.containsMouse || seekMouse.pressed

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: seekTrack.engaged ? 6 : 4
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.22)
                        Behavior on height { NumberAnimation { duration: 120 } }
                        Rectangle {
                            width: seekRow.progress * parent.width
                            height: parent.height
                            radius: height / 2
                            color: "#ffffff"
                        }
                    }
                    Rectangle {  // thumb
                        width: seekTrack.engaged ? 14 : 0
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: seekRow.progress * parent.width - width / 2
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !!im.s.hasTrack
                        property real dragMs: 0
                        function updateDrag(mx) {
                            const n = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                            dragMs = n * seekRow.durationMs
                        }
                        onPressed: (mouse) => updateDrag(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) updateDrag(mouse.x) }
                        onReleased: player.seek(dragMs)
                    }
                }

                Label {
                    text: "-" + Theme.fmt(Math.max(0, (im.s.durationMs || 0) - seekRow.currentMs))
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    Layout.preferredWidth: 38
                }
            }

            // Transport controls
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 22

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "shuffle"
                    size: 20
                    active: !!im.s.shuffle
                    tip: I18n.t("Shuffle")
                    onClicked: player.toggleShuffle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "previous"
                    size: 22
                    tip: I18n.t("Previous (Ctrl+←)")
                    onClicked: player.previous()
                }

                // round white play / pause button
                Rectangle {
                    width: 62
                    height: 62
                    radius: 31
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    scale: playMouse.pressed ? 0.94 : (playMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Icon {
                        anchors.centerIn: parent
                        glyph: im.s.isPlaying ? "pause" : "play"
                        size: 26
                        color: "#111111"
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player.togglePlay()
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "next"
                    size: 22
                    tip: I18n.t("Next (Ctrl+→)")
                    onClicked: player.next()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: im.s.repeat === "track" ? "repeat-one" : "repeat"
                    size: 20
                    active: im.s.repeat !== undefined && im.s.repeat !== "off"
                    tip: I18n.t("Repeat")
                    onClicked: player.cycleRepeat()
                }
            }

            // Volume
            RowLayout {
                id: volRow
                Layout.preferredWidth: Math.min(320, coverStage.side)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 12
                property int lastVol: 60
                readonly property int vol: (im.s.volume !== undefined && im.s.volume >= 0) ? im.s.volume : 80

                Icon {
                    glyph: volRow.vol === 0 ? "volume-off" : "volume"
                    size: 16
                    color: Qt.rgba(1, 1, 1, 0.72)
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (volRow.vol > 0) {
                                volRow.lastVol = volRow.vol
                                player.setVolume(0)
                            } else {
                                player.setVolume(volRow.lastVol || 60)
                            }
                        }
                    }
                }

                Item {
                    id: volBar
                    Layout.fillWidth: true
                    height: 20
                    readonly property real norm: Math.max(0, Math.min(1, volRow.vol / 100))

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.22)

                        Rectangle {
                            width: volBar.norm * parent.width
                            height: parent.height
                            radius: 2
                            color: "#ffffff"
                        }
                    }

                    Rectangle {  // thumb
                        width: 12
                        height: 12
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, volBar.norm * parent.width - width / 2))
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setFromX(mx) {
                            const pct = Math.round(Math.max(0, Math.min(1, mx / Math.max(1, width))) * 100)
                            player.setVolume(pct)
                        }
                        onPressed: (mouse) => setFromX(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                        onWheel: (wheel) => player.setVolume(Math.max(0, Math.min(100, volRow.vol + (wheel.angleDelta.y > 0 ? 5 : -5))))
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ---- RIGHT COLUMN: Lyrics / Equalizer / Queue ----
        ColumnLayout {
            visible: im.showPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: im.shown && im.showPanel
                sourceComponent: im.panel === "lyrics" ? lyricsComp
                               : im.panel === "equalizer" ? eqComp
                               : queueComp
            }

            // Compact controls when narrow window hides the left cover column
            RowLayout {
                visible: !im.wide
                Layout.fillWidth: true
                spacing: 16
                Cover {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    round: true
                    source: im.s.image || ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { Layout.fillWidth: true; text: im.s.name || ""; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.Bold }
                    SeekBar { Layout.fillWidth: true }
                }
                TransportControls { size: 20 }
            }
        }
    }

    Component { id: lyricsComp; LyricsView {} }
    Component { id: queueComp; QueueView {} }
    Component { id: eqComp; EqualizerView {} }
}
