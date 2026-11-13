import QtQuick
import QtQuick.Controls

// Whether one song is kept for offline, as a small button: an outlined arrow (click to
// download), a ring filling up while it downloads (click to cancel), a filled mark once done.
AbstractButton {
    id: db
    property var track: ({})
    property int size: 16
    property color tint: palette.windowText
    readonly property string uri: track && track.uri ? track.uri : ""
    // 101 downloaded, 0-100 downloading, -1 waiting, -2 not downloaded
    readonly property int dl: (downloads.revision, downloads.progressRevision, uri ? downloads.stateOf(uri) : -2)
    readonly property bool done: dl === 101
    readonly property bool busy: dl >= -1 && dl <= 100

    implicitWidth: size + 10
    implicitHeight: size + 10
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    enabled: uri.indexOf("yt:track:") === 0 || uri.indexOf("spotify:track:") === 0
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: height / 2
        color: db.down ? Theme.alpha(db.tint, 0.13) : db.hovered && !db.done ? Theme.alpha(db.tint, 0.08) : "transparent"
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            visible: !db.busy
            glyph: db.done ? "downloaded" : "download-circle"
            size: db.size
            color: db.done ? Theme.ok : db.tint
        }
        Canvas {
            id: ring
            anchors.centerIn: parent
            visible: db.busy
            width: db.size
            height: db.size
            property real progress: Math.max(0, db.dl) / 100
            property color ink: db.tint
            onProgressChanged: requestPaint()
            onInkChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                const r = width / 2 - 1.5
                ctx.reset()
                ctx.lineWidth = 2
                ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.25)
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke()
                ctx.strokeStyle = Theme.ok
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.max(0.04, progress) * 2 * Math.PI)
                ctx.stroke()
            }
            // waiting for its turn: the short arc goes round
            RotationAnimator on rotation {
                running: db.busy && db.dl < 0 && db.Window.active
                from: 0; to: 360; duration: 1200; loops: Animation.Infinite
            }
        }
        Icon {  // cancel
            anchors.centerIn: parent
            visible: db.busy && db.hovered
            glyph: "close"
            size: Math.round(db.size * 0.55)
            color: db.tint
        }
    }

    onClicked: {
        if (busy)
            downloads.remove(uri)
        else if (!done)
            downloads.download([track])
    }

    ToolTip.visible: hovered
    ToolTip.delay: 400
    ToolTip.text: done ? I18n.t("Downloaded — plays without internet")
                : dl === -1 ? I18n.t("Waiting to download — click to cancel")
                : busy ? I18n.t("Downloading {n}% — click to cancel", { n: dl })
                : I18n.t("Download for offline")
}
