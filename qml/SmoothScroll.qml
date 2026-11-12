import QtQuick

// Eased mouse-wheel scrolling for a Flickable/ListView.
//   mouse wheel: each notch glides (ease-out) instead of jumping; fast spins pile up
//                into one continuous glide toward the combined destination
//   touchpad:    pixel-precise deltas are applied 1:1, so it still follows the fingers
// Usage, inside the view:  SmoothScroll { flickable: myView }
WheelHandler {
    id: ws
    property Flickable flickable
    property real step: 132       // pixels per wheel notch
    property int duration: 340    // ms for one glide

    property real destination: 0
    readonly property NumberAnimation glide: NumberAnimation {
        target: ws.flickable
        property: "contentY"
        duration: ws.duration
        easing.type: Easing.OutCubic
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

    onWheel: (event) => {
        const f = flickable
        if (!f || f.contentHeight <= f.height) {
            event.accepted = false
            return
        }
        if (event.pixelDelta.y !== 0) {
            // touchpad: follow the gesture directly
            glide.stop()
            f.contentY = clamp(f.contentY - event.pixelDelta.y)
        } else if (event.angleDelta.y !== 0) {
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
