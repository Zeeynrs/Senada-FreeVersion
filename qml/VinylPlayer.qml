import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a turntable (Settings → Appearance → Full view style): a record spinning on
// the left edge with the cover as its label, a tonearm whose needle follows the song (drag
// it to seek), and the lyrics fanned out around the record like the spokes of a wheel,
// the sung line level with the record's centre. The queue fans out the same way
// (VinylQueueFan) and the equalizer is a spoke per band (VinylEqualizer). Controls sit in a
// strip along the bottom.
Item {
    id: vp
    property bool active: true            // the full view is on screen
    property string panel: "lyrics"       // "lyrics" | "queue" | "equalizer"
    property bool showPanel: true
    signal closeRequested()
    readonly property var s: player ? player.state : ({})

    // ---- geometry -------------------------------------------------------------------
    readonly property real topSpace: 68
    readonly property real bottomSpace: 116
    readonly property real areaH: height - topSpace - bottomSpace
    readonly property real discR: Math.max(120, Math.min(areaH * 0.52, width * 0.3))
    readonly property real cx: discR * 0.36            // about a third of the record is off-screen
    readonly property real cy: topSpace + areaH / 2
    readonly property real labelR: discR * 0.42
    readonly property real grooveOuter: discR * 0.93    // where the needle starts…
    readonly property real grooveInner: labelR + discR * 0.05   // …and where the song ends
    readonly property point pivot: Qt.point(cx + discR * 0.98, cy - discR * 0.86)
    readonly property real armLen: discR * 1.12
    readonly property real restAngle: 80                // arm parked beside the record

    readonly property real durationMs: Math.max(1, s.durationMs || 0)
    readonly property real progress: s.hasTrack ? Math.max(0, Math.min(1, (player ? player.position : 0) / durationMs)) : 0

    // arm angle (degrees, clockwise from pointing right) that puts the needle `r` from the centre
    function angleFor(r) {
        const dx = cx - pivot.x, dy = cy - pivot.y
        const d = Math.hypot(dx, dy)
        const c = (armLen * armLen + d * d - r * r) / (2 * armLen * d)
        return (Math.atan2(dy, dx) - Math.acos(Math.max(-1, Math.min(1, c)))) * 180 / Math.PI
    }
    function radiusFor(p) { return grooveOuter - p * (grooveOuter - grooveInner) }

    // ---- the record -----------------------------------------------------------------
    Item {
        id: disc
        x: vp.cx - vp.discR
        y: vp.cy - vp.discR
        width: vp.discR * 2
        height: width

        // vinyl with its grooves; nothing on it changes as it turns, so it is drawn once
        Canvas {
            id: grooves
            anchors.fill: parent
            visible: false
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                const r = width / 2
                ctx.reset()
                const g = ctx.createRadialGradient(r, r, 0, r, r, r)
                g.addColorStop(0, "#1c1c20")
                g.addColorStop(0.75, "#111114")
                g.addColorStop(1, "#060607")
                ctx.fillStyle = g
                ctx.beginPath(); ctx.arc(r, r, r, 0, 2 * Math.PI); ctx.fill()
                const inner = r * vp.grooveInner / vp.discR, outer = r * vp.grooveOuter / vp.discR
                ctx.lineWidth = 0.8
                for (let q = inner; q < outer; q += 2.2) {
                    ctx.strokeStyle = "rgba(255,255,255," + (0.03 + 0.03 * Math.abs(Math.sin(q * 0.37))).toFixed(3) + ")"
                    ctx.beginPath(); ctx.arc(r, r, q, 0, 2 * Math.PI); ctx.stroke()
                }
                // the smooth bands between tracks
                ctx.strokeStyle = "rgba(0,0,0,0.6)"
                ctx.lineWidth = 3
                for (const f of [0.6, 0.71, 0.82]) {
                    ctx.beginPath(); ctx.arc(r, r, r * f, 0, 2 * Math.PI); ctx.stroke()
                }
                ctx.strokeStyle = "rgba(255,255,255,0.12)"
                ctx.lineWidth = 1.5
                ctx.beginPath(); ctx.arc(r, r, r - 1.5, 0, 2 * Math.PI); ctx.stroke()
            }
        }
        MultiEffect {
            anchors.fill: grooves
            source: grooves
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.7
            shadowBlur: 1.0
            shadowVerticalOffset: 14
            shadowHorizontalOffset: 6
        }

        // light catching the grooves; it stays put while the record turns underneath
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                const r = width / 2
                ctx.reset()
                const g = ctx.createConicalGradient(r, r, -Math.PI / 4)
                g.addColorStop(0.0, "rgba(255,255,255,0)")
                g.addColorStop(0.06, "rgba(255,255,255,0.09)")
                g.addColorStop(0.13, "rgba(255,255,255,0)")
                g.addColorStop(0.5, "rgba(255,255,255,0)")
                g.addColorStop(0.56, "rgba(255,255,255,0.07)")
                g.addColorStop(0.63, "rgba(255,255,255,0)")
                g.addColorStop(1.0, "rgba(255,255,255,0)")
                ctx.fillStyle = g
                ctx.beginPath(); ctx.arc(r, r, r - 2, 0, 2 * Math.PI); ctx.fill()
            }
        }

        // the label (album cover) turns at 33⅓ rpm, easing in and out on play / pause
        Item {
            id: spin
            anchors.fill: parent
            property real speed: vp.active && vp.s.isPlaying ? 200 : 0   // degrees per second
            Behavior on speed { NumberAnimation { duration: 1100; easing.type: Easing.InOutQuad } }

            Rectangle {
                anchors.centerIn: parent
                width: vp.labelR * 2 + 6
                height: width
                radius: width / 2
                color: "#050505"
            }
            Cover {
                anchors.centerIn: parent
                width: vp.labelR * 2
                height: width
                round: true
                source: vp.s.imageLarge || vp.s.image || ""
            }
        }
        FrameAnimation {
            running: vp.active && spin.speed > 0.1
            onTriggered: spin.rotation = (spin.rotation + frameTime * spin.speed) % 360
        }

        // spindle
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(10, vp.discR * 0.05)
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#f4f4f4" }
                GradientStop { position: 1; color: "#8c8c8c" }
            }
            border.color: Qt.rgba(0, 0, 0, 0.5)
        }
    }

    // ---- tonearm ----------------------------------------------------------------------
    // drawn into its own layer so it can cast a shadow on the record
    Item {
        id: armLayer
        x: vp.pivot.x - vp.discR * 0.8
        y: vp.pivot.y - vp.discR * 0.45
        width: vp.discR * 1.3
        height: vp.discR * 1.8
        visible: false

        // pivot base
        Rectangle {
            x: vp.discR * 0.8 - width / 2
            y: vp.discR * 0.45 - height / 2
            width: vp.discR * 0.24
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a3a3e" }
                GradientStop { position: 1; color: "#18181a" }
            }
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }

        Item {
            id: arm
            x: vp.discR * 0.8
            y: vp.discR * 0.45
            property bool dragging: false
            property real dragProgress: 0
            readonly property real target: !vp.s.hasTrack ? vp.restAngle
                                         : vp.angleFor(vp.radiusFor(dragging ? dragProgress : vp.progress))
            property real angle: target
            Behavior on angle { enabled: !arm.dragging; SmoothedAnimation { velocity: 45 } }
            rotation: angle

            // counterweight
            Rectangle {
                x: -vp.discR * 0.27
                y: -height / 2
                width: vp.discR * 0.12
                height: vp.discR * 0.11
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: "#d6d6d6" }
                    GradientStop { position: 0.5; color: "#8a8a8a" }
                    GradientStop { position: 1; color: "#505050" }
                }
            }
            // rod
            Rectangle {
                x: -vp.discR * 0.15
                y: -height / 2
                width: vp.armLen * 0.86 + vp.discR * 0.15
                height: Math.max(4, vp.discR * 0.022)
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f5f5f5" }
                    GradientStop { position: 1; color: "#8f8f8f" }
                }
            }
            // headshell with the cartridge; the needle is at armLen
            Rectangle {
                id: head
                x: vp.armLen * 0.84
                y: -height / 2
                width: vp.armLen * 0.16 + vp.discR * 0.03
                height: vp.discR * 0.075
                radius: 3
                color: "#26262a"
                border.color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle {   // finger lift
                    anchors.right: parent.right
                    anchors.rightMargin: -width + 2
                    anchors.top: parent.top
                    anchors.topMargin: -2
                    width: vp.discR * 0.05
                    height: 3
                    radius: 1.5
                    color: "#bdbdbd"
                }
            }
            // pivot cap
            Rectangle {
                x: -width / 2
                y: -height / 2
                width: vp.discR * 0.1
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e9e9e9" }
                    GradientStop { position: 1; color: "#7a7a7a" }
                }
            }
        }
    }
    MultiEffect {
        anchors.fill: armLayer
        source: armLayer
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.65
        shadowBlur: 0.5
        shadowVerticalOffset: 10
        shadowHorizontalOffset: 8
    }

    // the needle in window coordinates, for the time label and for dragging
    readonly property point needle: Qt.point(
        pivot.x + armLen * Math.cos(arm.angle * Math.PI / 180),
        pivot.y + armLen * Math.sin(arm.angle * Math.PI / 180))

    // drag the headshell across the record to seek
    MouseArea {
        x: vp.needle.x - width / 2
        y: vp.needle.y - height / 2
        width: vp.discR * 0.34
        height: width
        enabled: !!vp.s.hasTrack
        hoverEnabled: true
        preventStealing: true
        cursorShape: arm.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        function progressAt(mouse) {
            const p = mapToItem(vp, mouse.x, mouse.y)
            const r = Math.hypot(p.x - vp.cx, p.y - vp.cy)
            return Math.max(0, Math.min(1, (vp.grooveOuter - r) / (vp.grooveOuter - vp.grooveInner)))
        }
        onPressed: (mouse) => { arm.dragProgress = vp.progress; arm.dragging = true }
        onPositionChanged: (mouse) => { if (arm.dragging) arm.dragProgress = progressAt(mouse) }
        onReleased: {
            player.seek(arm.dragProgress * vp.durationMs)
            arm.dragging = false
        }
        onCanceled: arm.dragging = false
        ToolTip.visible: containsMouse && !arm.dragging
        ToolTip.text: I18n.t("Drag the needle to seek")
        ToolTip.delay: 600
    }

    // elapsed time beside the needle
    Label {
        visible: !!vp.s.hasTrack
        x: vp.needle.x + 14
        y: vp.needle.y + 12
        text: Theme.fmt(arm.dragging ? arm.dragProgress * vp.durationMs : (player ? player.position : 0))
        color: Qt.rgba(1, 1, 1, 0.85)
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.35)
    }

    // ---- lyrics around the record -------------------------------------------------------
    Item {
        id: wheel
        anchors.fill: parent
        anchors.topMargin: vp.topSpace
        anchors.bottomMargin: vp.bottomSpace
        clip: true
        // lyrics and the queue both fan out here; the equalizer has its own spokes below
        visible: vp.showPanel && (vp.panel === "lyrics" || vp.panel === "queue")
        readonly property bool showLyrics: vp.panel === "lyrics"
        // lines fade out towards the top and towards the controls instead of being cut off
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: wheelMask
            // follow the gradient smoothly instead of cutting at the first bit of alpha
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        readonly property real ox: vp.cx                       // record centre, in wheel coordinates
        readonly property real oy: vp.cy - vp.topSpace
        readonly property real r0: vp.discR + Math.max(40, vp.discR * 0.16)   // lines start here
        readonly property real lineWidth: Math.max(200, Math.min(760, vp.width - ox - r0 - 56))
        readonly property int textSize: Math.round(Math.max(20, Math.min(30, vp.discR * 0.085)))
        readonly property real gap: 16
        readonly property real upLimit: 30      // above this the tonearm is in the way
        readonly property real downLimit: 62

        // arc length (at r0) of each line's middle; lines may wrap, so they are measured
        property var offsets: []
        function relayout() {
            const out = []
            let pos = 0, prev = 0
            for (let i = 0; i < rep.count; ++i) {
                const it = rep.itemAt(i)
                const h = it ? it.lineHeight : textSize * 1.4
                if (i > 0)
                    pos += prev / 2 + gap + h / 2
                out.push(pos)
                prev = h
            }
            offsets = out
        }

        // scrolling by hand moves the wheel; synced lyrics come back to the sung line after a while
        property real scroll: 0
        readonly property int focusIndex: lyrics.synced ? Math.max(0, lyrics.current) : 0
        readonly property real target: {
            const last = offsets.length ? offsets[offsets.length - 1] : 0
            const base = offsets.length > focusIndex ? offsets[focusIndex] : 0
            return Math.max(0, Math.min(last, base + scroll))
        }
        property real focusPos: target
        Behavior on focusPos { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
        Timer { id: scrollBack; interval: 4000; onTriggered: if (lyrics.synced) wheel.scroll = 0 }
        Connections {
            target: lyrics
            function onChanged() { wheel.scroll = 0 }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (!wheel.showLyrics) {
                    queueFan.scrollBy(-event.angleDelta.y * 0.5)
                    return
                }
                wheel.scroll -= event.angleDelta.y * 0.5
                scrollBack.restart()
            }
        }

        Repeater {
            id: rep
            model: wheel.showLyrics && lyrics.status === "ready" ? lyrics.lines : []
            onCountChanged: Qt.callLater(wheel.relayout)

            delegate: Item {
                id: spoke
                required property var modelData
                required property int index
                readonly property real lineHeight: line.implicitHeight
                onLineHeightChanged: Qt.callLater(wheel.relayout)
                Component.onCompleted: Qt.callLater(wheel.relayout)
                readonly property bool isCurrent: lyrics.synced && index === lyrics.current
                readonly property real deg: wheel.offsets.length > index
                    ? (wheel.offsets[index] - wheel.focusPos) / wheel.r0 * 180 / Math.PI : 999
                readonly property real fade: Math.max(0, Math.min(1,
                    (deg < 0 ? wheel.upLimit + deg : wheel.downLimit - deg) / 14))

                x: wheel.ox
                y: wheel.oy
                transformOrigin: Item.TopLeft
                rotation: deg
                visible: fade > 0

                Label {
                    id: line
                    x: wheel.r0
                    y: -height / 2
                    width: wheel.lineWidth
                    text: spoke.modelData.text || "♪"
                    wrapMode: Text.WordWrap
                    font.pixelSize: wheel.textSize
                    font.weight: Font.Bold
                    color: "#ffffff"
                    transformOrigin: Item.Left
                    scale: spoke.isCurrent ? 1.06 : 1.0
                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    opacity: spoke.fade * (spoke.isCurrent ? 1.0
                             : !lyrics.synced ? 0.85
                             : (spoke.index < lyrics.current ? 0.36 : 0.46) * (1 - Math.min(0.4, Math.abs(spoke.deg) / 90)))
                    Behavior on opacity { NumberAnimation { duration: 280 } }
                    HoverHandler { cursorShape: lyrics.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (lyrics.synced) player.seek(spoke.modelData.t) }
                }
            }
        }

        // loading / nothing found: said where the sung line would be
        Column {
            x: wheel.ox + wheel.r0
            y: wheel.oy - height / 2
            width: wheel.lineWidth
            spacing: 8
            visible: wheel.showLyrics && lyrics.status !== "ready"
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: ({ "loading": I18n.t("Loading lyrics…"), "none": I18n.t("No lyrics found for this song"),
                         "error": I18n.t("Could not load lyrics"), "idle": I18n.t("Play a song to see its lyrics") })[lyrics.status] || ""
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: Math.round(wheel.textSize * 0.75)
                font.weight: Font.Bold
            }
            Label {
                visible: lyrics.status === "none" && lyrics.source !== "auto"
                text: I18n.t("Try another source below.")
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 14
            }
        }

        // the queue, fanned out the same way
        VinylQueueFan {
            id: queueFan
            anchors.fill: parent
            visible: !wheel.showLyrics
            ox: wheel.ox
            oy: wheel.oy
            r0: wheel.r0
            lineWidth: wheel.lineWidth
            upLimit: wheel.upLimit
            downLimit: wheel.downLimit
        }
    }

    // the equalizer: a spoke per band around the record, and a pitch fader
    VinylEqualizer {
        anchors.fill: wheel
        visible: opacity > 0
        opacity: vp.showPanel && vp.panel === "equalizer" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        ox: wheel.ox
        oy: wheel.oy
        r0: wheel.r0
    }

    Item {
        id: wheelMask
        anchors.fill: wheel
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: Math.min(0.3, 50 / Math.max(1, wheelMask.height)); color: "#ffffff" }
                GradientStop { position: 1 - Math.min(0.3, 110 / Math.max(1, wheelMask.height)); color: "#ffffff" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    LyricsSourceButton {
        visible: wheel.visible && wheel.showLyrics && lyrics.status !== "idle"
        x: vp.width - width - 40
        y: vp.height - vp.bottomSpace - height - 2
        tint: Qt.rgba(1, 1, 1, 0.55)
        hoverTint: "#ffffff"
        fontSize: 13
    }


    // ---- nothing open on the right (cover-only): the song itself fills the space -------------
    // title, artist and the controls, centred between the record (with its tonearm) and the edge
    Item {
        id: spotlight
        readonly property real areaLeft: vp.cx + vp.discR * 1.3
        readonly property real areaRight: vp.width - 48
        x: areaLeft
        width: Math.max(0, areaRight - areaLeft)
        y: vp.topSpace
        height: vp.areaH + vp.bottomSpace * 0.5
        opacity: vp.showPanel ? 0 : 1
        visible: opacity > 0
        enabled: !vp.showPanel
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        readonly property var next: player && player.queue.length > 0 ? player.queue[0] : null

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 640)
            spacing: 6
            transform: Translate {
                y: vp.showPanel ? 24 : 0
                Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("NOW PLAYING")
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 2.4
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                horizontalAlignment: Text.AlignHCenter
                text: vp.s.name || I18n.t("Nothing is playing")
                color: "#ffffff"
                font.pixelSize: Math.round(Math.max(34, Math.min(72, spotlight.width * 0.075)))
                font.weight: Font.Black
                font.letterSpacing: -0.5
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                LinkLabel {
                    Layout.maximumWidth: spotlight.width - 90
                    text: vp.s.artists || ""
                    font.pixelSize: 20
                    color: Qt.rgba(1, 1, 1, 0.8)
                    elide: Text.ElideRight
                    onClicked: if (vp.s.artistId) { vp.closeRequested(); Nav.go("artist", vp.s.artistId) }
                }
                IconButton {
                    visible: !!vp.s.hasTrack
                    implicitWidth: 32
                    iconName: vp.s.liked ? "heart" : "heart-outline"
                    size: 18
                    tint: vp.s.liked ? Theme.like : Qt.rgba(1, 1, 1, 0.75)
                    tip: vp.s.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                    onClicked: player.toggleLike()
                }
                DownloadButton {
                    visible: !!vp.s.hasTrack
                    track: vp.s
                    size: 17
                    tint: Qt.rgba(1, 1, 1, 0.75)
                }
            }
            Label {
                visible: !!vp.s.album
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: vp.s.album || ""
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 14
                elide: Text.ElideRight
                HoverHandler { cursorShape: vp.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { onTapped: if (vp.s.albumId) { vp.closeRequested(); Nav.go("album", vp.s.albumId) } }
            }

            ImmersiveSeek {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 28
                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(520, spotlight.width * 0.85)
            }
            ImmersiveTransport {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                playSize: 66
                spacing: 26
            }
            ImmersiveVolume {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(280, spotlight.width * 0.5)
            }

            // what comes after this song
            Rectangle {
                visible: !!spotlight.next
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 26
                Layout.maximumWidth: spotlight.width
                implicitWidth: nextRow.implicitWidth + 24
                implicitHeight: 48
                radius: 24
                color: nextHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                Behavior on color { ColorAnimation { duration: 140 } }
                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: player.next() }
                ToolTip.visible: nextHover.hovered
                ToolTip.text: I18n.t("Next (Ctrl+→)")
                ToolTip.delay: 500
                RowLayout {
                    id: nextRow
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.Layout.maximumWidth - 24)
                    spacing: 10
                    Cover {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        source: spotlight.next ? (spotlight.next.imageSmall || "") : ""
                        simple: true
                    }
                    Label {
                        text: I18n.t("Up next")
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 13
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 360
                        text: spotlight.next ? (spotlight.next.name || "") + (spotlight.next.artists ? "  ·  " + spotlight.next.artists : "") : ""
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: vp.bottomSpace
        // the spotlight above carries them while nothing is open on the right
        opacity: vp.showPanel ? 1 : 0
        visible: opacity > 0
        enabled: vp.showPanel
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        onCloseRequested: vp.closeRequested()
    }
}
