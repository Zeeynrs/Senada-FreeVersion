import QtQuick

// The Senada "bloom" shape: a circle whose edge ripples into lobes (scallops/petals).
// Used for the play button, logo mark, artist avatars and decorative accents.
Canvas {
    id: s
    property color color: Theme.mint
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property int lobes: 12
    property real depth: 0.075      // lobe amplitude relative to the radius
    property real rotationPhase: 0  // radians; animate to make the edge "breathe"

    onColorChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onLobesChanged: requestPaint()
    onDepthChanged: requestPaint()
    onRotationPhaseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const cx = width / 2, cy = height / 2
        const outer = Math.min(cx, cy) - strokeWidth / 2
        const amp = outer * depth
        const base = outer - amp
        ctx.beginPath()
        const steps = Math.max(120, lobes * 16)
        for (let i = 0; i <= steps; i++) {
            const a = (i / steps) * Math.PI * 2
            const r = base + amp * Math.cos(lobes * (a - rotationPhase))
            const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()
        if (strokeWidth > 0) {
            ctx.lineWidth = strokeWidth
            ctx.strokeStyle = strokeColor
            ctx.stroke()
        }
    }
}
