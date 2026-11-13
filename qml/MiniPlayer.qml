import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

// The mini player ("dynamic island"): a black pill at the top of the screen while the main
// window is minimized. It shows the song, how far along it is, play / pause and a button back
// to the full window; the arrow opens it wider, with the controls and the lyrics.
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

    readonly property int margin: 12           // see-through room around the pill
    readonly property int compactW: 380
    readonly property int compactH: 60
    readonly property int wideW: 480           // senada/island.py SIZE = wideW/H + 2 * margin
    readonly property int wideH: 430

    title: "Senada mini player"
    width: wideW + 2 * margin
    height: wideH + 2 * margin
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    color: "transparent"
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
        y = screen.virtualY + 2
    }

    function updateInputArea() {
        if (visible)
            session.setInputArea(island, pill.x, pill.y, pill.width, pill.height)
    }
    onVisibleChanged: updateInputArea()


    Rectangle {
        id: pill
        objectName: "islandPill"
        x: Math.round((island.width - width) / 2)
        y: island.margin
        width: island.expanded ? island.wideW : island.compactW
        height: island.expanded ? island.wideH : island.compactH
        radius: island.expanded ? 28 : island.compactH / 2
        color: "#0b0b0c"
        border.width: 1
        border.color: island.playing ? Theme.alpha(Theme.mix(Theme.accent, Qt.rgba(1, 1, 1, 1), 0.35), 0.35) : Qt.rgba(1, 1, 1, 0.09)
        antialiasing: true
        clip: true

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

        // ---- the always-visible row ------------------------------------------------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: island.compactH

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
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: island.expanded ? 10 : 20
                    Behavior on radius { NumberAnimation { duration: 300 } }
                    source: island.s.imageSmall || island.s.image || ""
                    fallbackIcon: "music"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 40
                    spacing: 1
                    Label {
                        Layout.fillWidth: true
                        text: island.hasTrack ? island.s.name : I18n.t("Nothing playing yet")
                        elide: Text.ElideRight
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: island.hasTrack
                        text: island.s.artists || ""
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                    }
                }

                Label {
                    visible: island.hasTrack && !island.expanded
                    text: Theme.fmt(player.position) + " / " + Theme.fmt(island.s.durationMs)
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }

                // play / pause inside a ring that fills up as the song plays
                AbstractButton {
                    id: playButton
                    visible: !island.expanded
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
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.14)
                                strokeWidth: 2.5
                                fillColor: "transparent"
                                PathAngleArc { centerX: 19; centerY: 19; radiusX: 17; radiusY: 17; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: island.ink
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
                    iconName: "chevron-down"
                    size: 20
                    tint: Qt.rgba(1, 1, 1, 0.8)
                    rotation: island.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    onClicked: island.expanded = !island.expanded
                }
                IconButton {
                    iconName: "open-app"
                    size: 17
                    tint: Qt.rgba(1, 1, 1, 0.8)
                    onClicked: island.restore()
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
                clip: true

                LyricsView {
                    id: islandLyrics
                    anchors.fill: parent
                    textSize: 17
                    lineGap: 8
                    followHeight: true   // the lyrics open at the sung line as the pill grows
                }
                // lines fade out at the edges instead of being cut
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 28
                    gradient: Gradient {
                        GradientStop { position: 0; color: pill.color }
                        GradientStop { position: 1; color: Theme.alpha(pill.color, 0) }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 36
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.alpha(pill.color, 0) }
                        GradientStop { position: 1; color: pill.color }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Space"; onActivated: player.togglePlay() }
}
