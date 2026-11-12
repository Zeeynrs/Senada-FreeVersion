import QtQuick
import QtQuick.Effects

// App-wide backdrop: ink base, the playing cover blurred into a soft wash,
// two brand glows (mint & fuchsia) and faint flower silhouettes.
Item {
    id: amb
    property url art: ""

    Rectangle { anchors.fill: parent; color: Theme.bg }

    // brand glows: always there, so the app has colour even before anything plays
    Canvas {
        id: glows
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            function glow(x, y, r, rgb, a) {
                const g = ctx.createRadialGradient(x, y, 0, x, y, r)
                g.addColorStop(0, "rgba(" + rgb + "," + a + ")")
                g.addColorStop(1, "rgba(" + rgb + ",0)")
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            glow(width * 0.08, height * 0.02, Math.max(width, height) * 0.55, "111,242,198", 0.13)
            glow(width * 0.98, height * 0.95, Math.max(width, height) * 0.6, "255,79,139", 0.11)
        }
    }

    // the playing cover, blurred and darkened into an ambient wash
    Image {
        id: artImg
        anchors.fill: parent
        source: amb.art
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(128, 128)
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: artImg
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.35
        brightness: -0.38
        scale: 1.2
        opacity: artImg.status === Image.Ready ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    }

    // keep text readable: darken toward the bottom where lists and the dock live
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.bg, 0.25) }
            GradientStop { position: 0.55; color: Theme.alpha(Theme.bg, 0.55) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.bg, 0.82) }
        }
    }

    // flower silhouettes (the same family of shapes as the immersive player)
    Scallop { x: amb.width - width * 0.62; y: -height * 0.42; width: 300; height: 300; lobes: 18; depth: 0.16; color: Qt.rgba(1, 1, 1, 0.028) }
    Scallop { x: -width * 0.45; y: amb.height * 0.58; width: 260; height: 260; lobes: 7; depth: 0.28; color: Qt.rgba(1, 1, 1, 0.024) }
    Scallop { x: amb.width * 0.46; y: amb.height - height * 0.35; width: 180; height: 180; lobes: 10; depth: 0.12; color: Qt.rgba(1, 1, 1, 0.02) }
}
