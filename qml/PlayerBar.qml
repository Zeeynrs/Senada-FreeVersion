import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bottom player: now playing on the left, transport with the seek bar under it in the
// middle, and lyrics / queue panel toggles, devices, volume and full screen on the right.
Rectangle {
    id: bar
    property string panel: ""            // which right panel is open
    property bool floating: false        // a rounded card above the bottom edge (AppShell draws its shadow)
    signal openImmersive()
    signal openMiniPlayer()
    signal showPanel(string name)        // toggles "lyrics" / "queue"
    readonly property var s: player.state
    readonly property bool hasTrack: !!s.hasTrack
    readonly property bool roomy: width > 1000
    readonly property int volume: s.volume !== undefined && s.volume >= 0 ? s.volume : 0
    property int lastVolume: 50

    implicitHeight: Theme.playerBarHeight
    color: floating ? (Theme.glass ? Theme.sidebar : Theme.surface2) : Theme.sidebar
    radius: floating ? 20 : 0
    border.width: floating ? 1 : 0
    border.color: Theme.line

    Rectangle { visible: !bar.floating; width: parent.width; height: 1; color: Theme.line }
    Rectangle {  // liquid-glass sheen along the top
        x: bar.radius
        y: 1
        width: parent.width - 2 * bar.radius
        height: 1
        color: Theme.sheen
    }

    // ---- now playing ------------------------------------------------------------------
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(bar.width * 0.28, 320)
        spacing: 12

        Item {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            Cover {
                anchors.fill: parent
                radius: 6
                source: bar.s.imageSmall || bar.s.image || ""
                fallbackIcon: "music"
            }
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.45)
                visible: coverHover.hovered && bar.hasTrack
                Icon { anchors.centerIn: parent; glyph: "expand"; size: 18; color: "#ffffff" }
            }
            HoverHandler { id: coverHover; cursorShape: bar.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (bar.hasTrack) bar.openImmersive() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 60
            spacing: 2
            Item {
                id: titleRow
                Layout.fillWidth: true
                implicitHeight: 26
                Label {
                    id: titleLabel
                    width: Math.max(0, Math.min(implicitWidth, titleRow.width - 58))
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.hasTrack ? bar.s.name : I18n.t("Nothing playing yet")
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    HoverHandler { cursorShape: bar.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (bar.s.albumId) Nav.go("album", bar.s.albumId) }
                }
                IconButton {
                    x: titleLabel.width + 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.hasTrack
                    implicitWidth: 26
                    iconName: bar.s.liked ? "heart" : "heart-outline"
                    size: 16
                    tint: bar.s.liked ? Theme.like : Theme.dim
                    tip: bar.s.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                    onClicked: player.toggleLike()
                }
                DownloadButton {
                    x: titleLabel.width + 30
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.hasTrack
                    track: bar.s
                    size: 15
                    tint: Theme.dim
                }
            }
            LinkLabel {
                Layout.fillWidth: true
                font.pixelSize: 12
                text: bar.hasTrack ? bar.s.artists : I18n.t("Pick a song to start")
                onClicked: Nav.goArtist(bar.s)
            }
        }
    }

    // ---- transport + seek ------------------------------------------------------------
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(bar.width * 0.38, 520)
        spacing: 2

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "shuffle"; size: 18; tint: Theme.dim
                active: !!bar.s.shuffle
                tip: I18n.t("Shuffle")
                onClicked: player.toggleShuffle()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "previous"; size: 22
                tip: I18n.t("Previous (Ctrl+←)")
                onClicked: player.previous()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: bar.hasTrack && bar.s.isPlaying === true ? "pause" : "play"
                size: 22
                filled: true
                enabled: bar.hasTrack || player.queue.length > 0
                tip: I18n.t("Play/Pause (Space)")
                onClicked: player.togglePlay()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "next"; size: 22
                tip: I18n.t("Next (Ctrl+→)")
                onClicked: player.next()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: bar.s.repeat === "track" ? "repeat-one" : "repeat"
                size: 18; tint: Theme.dim
                active: bar.s.repeat !== undefined && bar.s.repeat !== "off"
                tip: I18n.t("Repeat")
                onClicked: player.cycleRepeat()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Theme.fmt(seek.pressed ? seek.value : player.position)
                color: Theme.dim
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
            Slider {
                id: seek
                Layout.fillWidth: true
                implicitHeight: 18
                padding: 0
                from: 0
                to: Math.max(1, bar.s.durationMs || 0)
                enabled: bar.hasTrack
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Binding on value {
                    value: player.position
                    when: !seek.pressed
                    restoreMode: Binding.RestoreNone
                }
                onPressedChanged: if (!pressed) player.seek(value)

                // "line" keeps the bar's own look (knob always shown); the other seek bar
                // styles from Settings → Appearance are drawn by SeekTrack
                readonly property bool plain: session.seekStyle === "line"
                background: Item {
                    x: seek.leftPadding
                    y: seek.topPadding
                    width: seek.availableWidth
                    height: seek.availableHeight
                    Rectangle {
                        visible: seek.plain
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.surface3
                        Rectangle {
                            width: seek.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.primary
                        }
                    }
                    SeekTrack {
                        visible: !seek.plain
                        anchors.fill: parent
                        trackStyle: session.seekStyle
                        progress: seek.visualPosition
                        fill: Theme.primary
                        rest: Theme.surface3
                        knob: Theme.primary
                        engaged: seek.hovered || seek.pressed
                        playing: !!bar.s.isPlaying
                        seed: bar.s.uri || ""
                    }
                }
                handle: Rectangle {
                    x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                    y: seek.topPadding + seek.availableHeight / 2 - height / 2
                    width: 13; height: 13; radius: 6.5
                    color: Theme.primary
                    visible: bar.hasTrack && seek.plain
                    scale: seek.hovered || seek.pressed ? 1 : 0.85
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }
                // time under the pointer
                Rectangle {
                    visible: seekHover.hovered && bar.hasTrack
                    readonly property real f: Math.max(0, Math.min(1, seekHover.point.position.x / seek.width))
                    x: Math.max(0, Math.min(seek.width - width, f * seek.width - width / 2))
                    y: -height - 6
                    width: hoverTime.implicitWidth + 14
                    height: 22
                    radius: 6
                    color: Theme.surface2
                    border.color: Theme.line
                    Label {
                        id: hoverTime
                        anchors.centerIn: parent
                        text: Theme.fmt(parent.f * (bar.s.durationMs || 0))
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                }
                HoverHandler { id: seekHover }
            }
            Label {
                Layout.preferredWidth: 40
                text: Theme.fmt(bar.s.durationMs)
                color: Theme.dim
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }
    }

    // ---- panels, devices, volume, full screen ----------------------------------------------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "lyrics"; size: 18; tint: Theme.dim
            active: bar.panel === "lyrics"
            tip: I18n.t("Lyrics")
            onClicked: bar.showPanel("lyrics")
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "queue"; size: 18; tint: Theme.dim
            active: bar.panel === "queue"
            tip: I18n.t("Queue")
            onClicked: bar.showPanel("queue")
        }
        IconButton {
            id: devButton
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.roomy
            iconName: "devices"; size: 18; tint: Theme.dim
            tip: I18n.t("Devices")
            active: !!bar.s.deviceId && bar.s.deviceId !== "local"
            onClicked: devices.opened ? devices.close() : devices.open()
            DevicesPopup {
                id: devices
                x: devButton.width - width
                y: -height - 12
            }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: bar.volume === 0 ? "volume-off" : "volume"
            size: 18; tint: Theme.dim
            tip: bar.volume === 0 ? I18n.t("Unmute") : I18n.t("Mute")
            onClicked: {
                if (bar.volume > 0) { bar.lastVolume = bar.volume; player.setVolume(0) }
                else player.setVolume(bar.lastVolume || 50)
            }
        }
        NSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: bar.roomy ? 110 : 76
            from: 0; to: 100
            value: bar.volume
            onMoved: player.setVolume(Math.round(value))
            WheelHandler {
                onWheel: (event) => player.setVolume(Math.max(0, Math.min(100, bar.volume + (event.angleDelta.y > 0 ? 2 : -2))))
            }
            ToolTip.visible: hovered
            ToolTip.text: "Volume " + bar.volume + "%"
            ToolTip.delay: 300
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "mini-player"; size: 18; tint: Theme.dim
            enabled: bar.hasTrack
            tip: I18n.t("Mini player (Ctrl+M)")
            onClicked: bar.openMiniPlayer()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "expand"; size: 18; tint: Theme.dim
            enabled: bar.hasTrack
            tip: I18n.t("Full screen (Ctrl+L)")
            onClicked: bar.openImmersive()
        }
    }
}
