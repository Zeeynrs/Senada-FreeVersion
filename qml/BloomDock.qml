import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// The floating "Bloom Dock": mini player and navigation in one glass capsule.
// A wavy mint seek line rides along its top edge.
Item {
    id: dock
    property string currentKey
    signal openImmersive()
    readonly property var s: player.state
    readonly property bool hasTrack: !!s.hasTrack
    readonly property bool roomy: width > 940

    implicitHeight: 78

    // soft drop shadow under the capsule
    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: height / 2
        color: Theme.panel
        border.color: Theme.glassBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowBlur: 1.0
            shadowVerticalOffset: 10
        }
    }
    // faint album tint inside the glass
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: height / 2
        color: Theme.alpha(Theme.accent, dock.hasTrack ? 0.07 : 0)
        Behavior on color { ColorAnimation { duration: 700 } }
    }

    // ---- wavy seek line along the top edge ------------------------------------
    Item {
        id: seek
        x: dock.height / 2
        width: dock.width - dock.height
        y: -6
        height: 14
        enabled: dock.hasTrack
        readonly property real frac: dragging ? dragFrac
                                   : (dock.s.durationMs > 0 ? Math.min(1, player.position / dock.s.durationMs) : 0)
        property bool dragging: false
        property real dragFrac: 0

        readonly property real px: Math.max(0, Math.min(width, frac * width))
        readonly property real wavelength: 44  // 2*pi*7 px, one period of the drawn sine

        // remaining part: a quiet straight line
        Rectangle {
            x: seek.px
            width: seek.width - seek.px
            height: 2
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.13)
        }
        // played part: a mint wave, drawn once and slid sideways (no per-frame repaint)
        Item {
            width: seek.px
            height: parent.height
            clip: true
            Canvas {
                id: wave
                width: seek.width + seek.wavelength
                height: parent.height
                property real amp: dock.s.isPlaying === true ? 3 : 1.2
                onAmpChanged: requestPaint()
                onWidthChanged: requestPaint()
                NumberAnimation on x {
                    running: dock.s.isPlaying === true && dock.visible
                    from: -seek.wavelength; to: 0
                    duration: 1800
                    loops: Animation.Infinite
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const mid = height / 2
                    ctx.strokeStyle = "" + Theme.mint
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    for (let x = 0; x <= width; x += 2) {
                        const y = mid + Math.sin(x / 7) * amp
                        if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
        }
        Rectangle {  // thumb
            width: seekArea.containsMouse || seek.dragging ? 14 : 10
            height: width
            radius: width / 2
            color: Theme.mint
            visible: dock.hasTrack
            x: seek.frac * seek.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            border.color: Theme.bg
            border.width: 2
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: seekArea
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            cursorShape: dock.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
            function fracAt(x) { return Math.max(0, Math.min(1, x / seek.width)) }
            onPressed: (m) => { seek.dragging = true; seek.dragFrac = fracAt(m.x) }
            onPositionChanged: (m) => { if (seek.dragging) seek.dragFrac = fracAt(m.x) }
            onReleased: {
                player.seek(Math.round(seek.dragFrac * (dock.s.durationMs || 0)))
                seek.dragging = false
            }
        }
        // time bubble while hovering / dragging
        Rectangle {
            visible: seekArea.containsMouse && dock.hasTrack
            readonly property real f: seek.dragging ? seek.dragFrac : seekArea.fracAt(seekArea.mouseX)
            x: Math.max(0, Math.min(seek.width - width, f * seek.width - width / 2))
            y: -height - 6
            width: tLabel.implicitWidth + 16
            height: 24
            radius: 12
            color: Theme.surface3
            Label {
                id: tLabel
                anchors.centerIn: parent
                text: Theme.fmt(parent.f * (dock.s.durationMs || 0))
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }
    }

    // ---- content -------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 6

        // now playing: scalloped cover (opens the immersive view) + title/artist
        Item {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            Cover {
                anchors.fill: parent
                scalloped: true
                scallops: 14
                scallopDepth: 0.05
                source: dock.s.image || ""
                fallbackIcon: "note"
                scale: coverHover.hovered ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 160 } }
            }
            HoverHandler { id: coverHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: dock.openImmersive() }
            ToolTip.visible: coverHover.hovered
            ToolTip.text: "Tampilan penuh + lirik (Ctrl+L)"
            ToolTip.delay: 500
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 90
            Layout.maximumWidth: 260
            Layout.leftMargin: 6
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: dock.hasTrack ? dock.s.name : "Belum ada yang diputar"
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.DemiBold
                HoverHandler { cursorShape: dock.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { onTapped: if (dock.s.albumId) Nav.go("album", dock.s.albumId) }
            }
            LinkLabel {
                Layout.fillWidth: true
                text: dock.hasTrack ? dock.s.artists : "Pilih lagu untuk mulai"
                onClicked: if (dock.s.artistId) Nav.go("artist", dock.s.artistId)
            }
        }
        IconButton {
            visible: dock.hasTrack
            iconName: dock.s.liked ? "heart" : "heart-outline"
            size: 18
            tint: dock.s.liked ? Theme.fuchsia : Theme.dim
            tip: dock.s.liked ? "Hapus dari Lagu Disukai" : "Simpan ke Lagu Disukai"
            onClicked: player.toggleLike()
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

        // transport
        IconButton {
            visible: dock.roomy
            iconName: "shuffle"; size: 18
            active: !!dock.s.shuffle
            tint: Theme.dim
            tip: "Acak"
            onClicked: player.toggleShuffle()
        }
        IconButton { iconName: "previous"; size: 22; tip: "Sebelumnya (Ctrl+←)"; onClicked: player.previous() }
        BloomPlayButton {
            size: 54
            playing: dock.s.isPlaying === true
            enabled: dock.hasTrack || player.queue.length > 0
            onClicked: player.togglePlay()
        }
        IconButton { iconName: "next"; size: 22; tip: "Berikutnya (Ctrl+→)"; onClicked: player.next() }
        IconButton {
            visible: dock.roomy
            iconName: dock.s.repeat === "track" ? "repeat-one" : "repeat"
            size: 18
            active: dock.s.repeat !== undefined && dock.s.repeat !== "off"
            tint: Theme.dim
            tip: "Ulangi"
            onClicked: player.cycleRepeat()
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

        Label {
            visible: dock.roomy && dock.hasTrack
            text: Theme.fmt(player.position) + " / " + Theme.fmt(dock.s.durationMs)
            color: Theme.dim
            font.pixelSize: 12
            font.features: { "tnum": 1 }
            Layout.rightMargin: 6
        }

        // extras: lyrics/immersive, devices, volume
        IconButton {
            iconName: "lyrics"; size: 18; tint: Theme.dim
            tip: "Lirik & tampilan penuh (Ctrl+L)"
            onClicked: dock.openImmersive()
        }
        IconButton {
            id: devButton
            iconName: "devices"; size: 18; tint: Theme.dim
            tip: "Perangkat"
            active: !!dock.s.deviceId && dock.s.deviceId !== "local"  // playing somewhere else
            onClicked: devices.opened ? devices.close() : devices.open()
            DevicesPopup {
                id: devices
                x: devButton.width - width
                y: -height - 28
            }
        }
        IconButton {
            id: volButton
            readonly property int volume: dock.s.volume !== undefined && dock.s.volume >= 0 ? dock.s.volume : 0
            iconName: volume === 0 ? "volume-off" : "volume"
            size: 18; tint: Theme.dim
            tip: "Volume " + volume + "% (gulir untuk mengubah)"
            onClicked: volPopup.opened ? volPopup.close() : volPopup.open()
            WheelHandler {
                onWheel: (event) => player.setVolume(Math.max(0, Math.min(100, volButton.volume + (event.angleDelta.y > 0 ? 5 : -5))))
            }
            Popup {
                id: volPopup
                x: volButton.width / 2 - width / 2
                y: -height - 28
                width: 260
                padding: 14
                background: Rectangle { color: Theme.surface2; radius: 22; border.color: Theme.glassBorder }
                contentItem: VolumeControl { sliderWidth: 170 }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 34
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: Theme.glassBorder
        }

        // navigation
        Repeater {
            model: [
                { key: "home", icon: "home", tip: "Beranda" },
                { key: "search", icon: "search", tip: "Cari (Ctrl+F)" },
                { key: "library", icon: "library", tip: "Library" },
                { key: "settings", icon: "settings", tip: "Pengaturan (Ctrl+,)" }
            ]
            IconButton {
                required property var modelData
                iconName: modelData.icon
                size: 20
                active: dock.currentKey === modelData.key
                tint: Theme.dim
                tip: modelData.tip
                onClicked: Nav.go(modelData.key)
            }
        }
    }
}
