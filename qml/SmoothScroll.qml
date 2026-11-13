import QtQuick

// Smooth scrolling for a Flickable/ListView.
//   mouse wheel: each notch glides (ease-out) instead of jumping; fast spins pile up
//                into one continuous glide toward the combined destination
//   touchpad:    follows the fingers directly (a little faster than 1:1), and when the
//                fingers lift mid-swipe the content keeps coasting and slows down
//                gradually (kinetic scrolling), like in a browser
// Usage, inside the view:  SmoothScroll { flickable: myView }
WheelHandler {
    id: ws
    property Flickable flickable
    property real step: 132           // pixels per wheel notch
    property int duration: 340        // ms for one glide
    property real touchpadSpeed: 1.5  // touchpad distance multiplier
    property real coastTime: 0.42     // s; how long the coast lingers (higher = glides further)
    property real maxCoastSpeed: 7000 // px/s

    property real destination: 0
    readonly property NumberAnimation glide: NumberAnimation {
        target: ws.flickable
        property: "contentY"
        duration: ws.duration
        easing.type: Easing.OutCubic
    }

    // ---- kinetic coast after a touchpad swipe --------------------------------------
    property var samples: []      // recent touchpad moves: { t: ms, dy: px, dt: ms }
    property real lastTouch: 0
    property real velocity: 0     // px/s, positive = content moves down (contentY falls)
    property bool sawPhases: false
    property real coastY: 0       // where the coast last put contentY

    readonly property FrameAnimation coast: FrameAnimation {
        onTriggered: {
            const f = ws.flickable
            // something else moved the content (scrollbar drag, jump to the sung line):
            // let it win
            if (!f || Math.abs(f.contentY - ws.coastY) > 1) { stop(); return }
            const dt = Math.min(frameTime, 0.05)
            ws.velocity *= Math.exp(-dt / ws.coastTime)
            const y = ws.clamp(f.contentY - ws.velocity * dt)
            if (Math.abs(ws.velocity) < 12 || y === f.contentY) {
                stop()
                return
            }
            f.contentY = y
            ws.coastY = y
        }
    }
    // Sources that do not report when the fingers lift (no scroll phases): treat a short
    // pause in the stream of touchpad events as the lift.
    readonly property Timer liftGuess: Timer {
        interval: 60
        onTriggered: ws.release()
    }

    target: null
    orientation: Qt.Vertical
    acceptedModifiers: Qt.NoModifier  // keep Ctrl/Shift+wheel free for other uses

    function clamp(y) {
        const f = flickable
        const top = f.originY - f.topMargin
        const bottom = Math.max(top, f.originY + f.contentHeight + f.bottomMargin - f.height)
        return Math.max(top, Math.min(bottom, y))
    }

    function stopAll() {
        glide.stop()
        coast.stop()
        liftGuess.stop()
    }

    // Fingers lifted: keep going at the speed of the last ~100 ms of the swipe.
    function release() {
        liftGuess.stop()
        const now = Date.now()
        const recent = samples.filter(s => now - s.t <= 100)
        samples = []
        // the fingers had already stopped before lifting: no coast
        if (recent.length < 2 || now - lastTouch > 70)
            return
        let dist = 0, time = 0
        for (const s of recent) { dist += s.dy; time += s.dt }
        const v = dist / Math.max(time, 8) * 1000
        if (Math.abs(v) < 120)
            return
        velocity = Math.max(-maxCoastSpeed, Math.min(maxCoastSpeed, v))
        coastY = flickable.contentY
        coast.start()
    }

    onWheel: (event) => {
        const f = flickable
        if (!f || f.contentHeight <= f.height) {
            event.accepted = false
            return
        }
        if (event.phase !== Qt.NoScrollPhase)
            sawPhases = true

        if (event.phase === Qt.ScrollEnd) {
            release()
            event.accepted = true
            return
        }

        if (event.pixelDelta.y !== 0) {
            // touchpad (Wayland/X11/macOS): follow the fingers directly
            stopAll()
            const now = Date.now()
            const dy = event.pixelDelta.y * touchpadSpeed
            const dt = lastTouch > 0 ? Math.min(now - lastTouch, 40) : 16
            lastTouch = now
            samples = samples.filter(s => now - s.t <= 150).concat([{ t: now, dy: dy, dt: dt }])
            f.contentY = clamp(f.contentY - dy)
            if (!sawPhases)
                liftGuess.restart()
        } else if (event.angleDelta.y !== 0 && event.angleDelta.y % 120 !== 0) {
            // high-resolution deltas (Windows precision touchpad, free-spinning wheels):
            // many tiny steps that already carry the system's own momentum, so apply them
            // straight away instead of restarting a glide for each one
            stopAll()
            f.contentY = clamp(f.contentY - event.angleDelta.y / 120 * step)
        } else if (event.angleDelta.y !== 0) {
            coast.stop()
            liftGuess.stop()
            const start = glide.running ? destination : f.contentY
            destination = clamp(start - event.angleDelta.y / 120 * step)
            if (destination === f.contentY) {
                event.accepted = false  // already at the edge: let a parent view scroll
                return
            }
            glide.from = f.contentY
            glide.to = destination
            glide.restart()
        }
        event.accepted = true
    }
}
