import QtQuick

// How far the song is, drawn in the style picked in Settings → Appearance → Seek bar:
//   line   a thin bar that thickens under the mouse (the default)
//   wave   the played part ripples like a wave while the song plays, flat when paused
//   bars   a waveform of bars, the played ones filled; each song gets its own shape
//   dots   a dotted line with a bigger dot where the song is
// Only draws: the slider or mouse area around it does the seeking.
Item {
    id: t
    property string trackStyle: "line"
    property real progress: 0
    property color fill: palette.windowText
    property color rest: Qt.rgba(0.5, 0.5, 0.5, 0.3)
    property color knob: fill
    property bool engaged: false     // under the mouse or being dragged
    property bool playing: false
    property string seed: ""         // the song, so its waveform keeps the same shape
    readonly property real px: Math.max(0, Math.min(1, progress)) * width
    implicitHeight: 20

    // ---- line ------------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: t.trackStyle !== "wave" && t.trackStyle !== "bars" && t.trackStyle !== "dots"
        Rectangle {
            y: (parent.height - height) / 2
            width: parent.width
            height: t.engaged ? 6 : 4
            radius: height / 2
            color: t.rest
            Behavior on height { NumberAnimation { duration: 120 } }
            Rectangle {
                width: t.px
                height: parent.height
                radius: height / 2
                color: t.fill
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        Rectangle {
            x: Math.max(0, Math.min(t.width - width, t.px - width / 2))
            y: (parent.height - height) / 2
            width: 14
            height: 14
            radius: 7
            color: t.knob
            opacity: t.engaged ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    // ---- wave ------------------------------------------------------------------------------
    Canvas {
        id: wave
        anchors.fill: parent
        visible: t.trackStyle === "wave"
        property real phase: 0
        property real amp: t.playing ? 1 : 0          // ripples only while playing
        Behavior on amp { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        onAmpChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        Connections {
            target: t
            function onProgressChanged() { if (wave.visible && !waveClock.running) wave.requestPaint() }
            function onFillChanged() { wave.requestPaint() }
            function onRestChanged() { wave.requestPaint() }
        }
        // only while Senada is the window in use: an endless animation keeps Qt redrawing
        FrameAnimation {
            id: waveClock
            running: wave.visible && wave.amp > 0.01 && t.Window.active
            onTriggered: { wave.phase = (wave.phase + frameTime * 5) % (2 * Math.PI); wave.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const mid = height / 2, end = t.px, gap = 6
            ctx.lineCap = "round"
            ctx.lineWidth = 3
            ctx.strokeStyle = t.rest
            if (end + gap < width) {
                ctx.beginPath(); ctx.moveTo(Math.min(width, end + gap), mid); ctx.lineTo(width - 1.5, mid); ctx.stroke()
            }
            if (end - gap > 1.5) {
                ctx.strokeStyle = t.fill
                ctx.beginPath()
                const a = 3.2 * amp, k = 2 * Math.PI / 22
                for (let x = 1.5; x <= end - gap; x += 1) {
                    const taper = Math.min(1, x / 10, (end - gap - x) / 10)   // calm at both ends
                    const y = mid + a * taper * Math.sin(x * k - phase)
                    if (x === 1.5) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
        }
    }
    Rectangle {  // the wave's knob: a short upright bar
        visible: t.trackStyle === "wave"
        x: Math.max(0, Math.min(t.width - width, t.px - width / 2))
        y: (t.height - height) / 2
        width: 5
        height: t.engaged ? 20 : 15
        radius: 2.5
        color: t.knob
        Behavior on height { NumberAnimation { duration: 120 } }
    }

    // ---- bars --------------------------------------------------------------------------------
    Canvas {
        id: bars
        anchors.fill: parent
        visible: t.trackStyle === "bars"
        readonly property real step: 4
        // bar heights 0..1 from the song's id, smooth like a real waveform
        readonly property var shape: {
            let h = 2166136261
            for (let i = 0; i < t.seed.length; i++) h = Math.imul(h ^ t.seed.charCodeAt(i), 16777619) >>> 0
            const a = (h % 1000) / 1000 * 6.28, b = ((h >>> 10) % 1000) / 1000 * 6.28, c = ((h >>> 20) % 1000) / 1000
            const n = Math.max(1, Math.floor(width / step))
            const out = []
            for (let i = 0; i < n; i++) {
                const x = i / n
                let v = 0.55 * Math.abs(Math.sin(i * 0.31 + a)) + 0.35 * Math.abs(Math.sin(i * 0.083 + b))
                v += 0.25 * Math.abs(Math.sin(i * 1.7 + c * 9))
                v *= 0.55 + 0.45 * Math.sin(Math.PI * Math.min(1, x * 1.15))   // quieter intro and outro
                out.push(Math.max(0.12, Math.min(1, v)))
            }
            return out
        }
        onShapeChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Connections {
            target: t
            function onProgressChanged() { if (bars.visible) bars.requestPaint() }
            function onFillChanged() { bars.requestPaint() }
            function onRestChanged() { bars.requestPaint() }
            function onEngagedChanged() { bars.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const mid = height / 2, maxH = height * (t.engaged ? 0.95 : 0.8)
            for (let i = 0; i < shape.length; i++) {
                const x = i * step + 0.5
                const h = Math.max(2, shape[i] * maxH)
                ctx.fillStyle = x + 1.5 <= t.px ? t.fill : t.rest
                ctx.fillRect(x, mid - h / 2, 2.5, h)
            }
        }
    }

    // ---- dots --------------------------------------------------------------------------------
    Canvas {
        id: dots
        anchors.fill: parent
        visible: t.trackStyle === "dots"
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        Connections {
            target: t
            function onProgressChanged() { if (dots.visible) dots.requestPaint() }
            function onFillChanged() { dots.requestPaint() }
            function onRestChanged() { dots.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const mid = height / 2, step = 7
            for (let x = 3; x < width - 2; x += step) {
                const played = x <= t.px
                ctx.fillStyle = played ? t.fill : t.rest
                ctx.beginPath()
                ctx.arc(x, mid, played ? 2.2 : 1.8, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }
    Rectangle {  // the dots' knob
        visible: t.trackStyle === "dots"
        x: Math.max(0, Math.min(t.width - width, t.px - width / 2))
        y: (t.height - height) / 2
        width: t.engaged ? 14 : 10
        height: width
        radius: width / 2
        color: t.knob
        Behavior on width { NumberAnimation { duration: 120 } }
    }
}
