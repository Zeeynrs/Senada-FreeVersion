import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full-window "now playing": round cover inside a circular visualizer (bars & wave),
// seek and volume bars, synced lyrics, queue and equalizer, on the blurred cover art.
// With the vinyl, poster or cinema full view style (wide windows) its own player (VinylPlayer,
// PosterPlayer, CinemaPlayer) takes the place of the cover and lyrics columns.
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
    readonly property string fullStyle: session ? session.immersiveStyle : "visualizer"
    // a style with its own layout replaces the columns below
    readonly property var stagedStyles: ["vinyl", "poster", "cinema"]
    readonly property bool staged: wide && stagedStyles.indexOf(fullStyle) >= 0
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

    Loader {
        anchors.fill: parent
        active: im.staged && im.shown
        sourceComponent: im.fullStyle === "poster" ? posterComp : im.fullStyle === "cinema" ? cinemaComp : vinylComp
    }
    Component {
        id: vinylComp
        VinylPlayer {
            active: im.shown
            panel: im.panel
            showPanel: im.showPanel
            onCloseRequested: im.close()
        }
    }
    Component {
        id: cinemaComp
        CinemaPlayer {
            active: im.shown
            panel: im.panel
            showPanel: im.showPanel
            onCloseRequested: im.close()
        }
    }
    Component {
        id: posterComp
        PosterPlayer {
            active: im.shown
            panel: im.panel
            showPanel: im.showPanel
            onCloseRequested: im.close()
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
                    visible: !im.staged
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
        visible: !im.staged
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
                    visible: coverStage.visOn && !im.staged
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
                    source: Theme.hiRes(im.s.imageLarge || im.s.image, 1200)
                    fallback: im.s.imageLarge || im.s.image || ""
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
                        onClicked: if (im.s.artistId || im.s.artists) { im.close(); Nav.goArtist(im.s) }
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

            ImmersiveSeek {
                Layout.preferredWidth: Math.min(360, coverStage.side + 20)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
            }

            ImmersiveTransport {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
            }

            ImmersiveVolume {
                Layout.preferredWidth: Math.min(320, coverStage.side)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
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
                active: im.shown && im.showPanel && !im.staged
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
