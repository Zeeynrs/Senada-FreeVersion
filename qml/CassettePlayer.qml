import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a cassette (Settings → Appearance → Full view style). The tape winds from the
// left reel onto the right one as the song plays, so the reels show how far along it is; the
// reels turn at a real cassette's pace (the emptier one spins faster). Beside it: the lyrics
// written on a ruled paper card (the sung line marked with a highlighter), the queue as a
// mixtape's handwritten track list, or the equalizer as a tape deck's front panel. Clicking
// the cassette plays / pauses. The controls sit in a strip along the bottom.
Item {
    id: cp
    property bool active: true            // the full view is on screen
    property string panel: "lyrics"       // "lyrics" | "queue" | "equalizer"
    property bool showPanel: true
    signal closeRequested()
    readonly property var s: player ? player.state : ({})

    readonly property real topSpace: 68
    readonly property real bottomSpace: 116
    readonly property real areaH: height - topSpace - bottomSpace
    readonly property real durationMs: Math.max(1, s.durationMs || 0)
    readonly property real progress: s.hasTrack ? Math.max(0, Math.min(1, (player ? player.position : 0) / durationMs)) : 0


    // ---- where things go -------------------------------------------------------------------
    // with something open on the right the cassette takes the left part, else the middle
    readonly property real stageW: showPanel ? width * 0.58 : width
    readonly property real cassetteW: Math.max(260, Math.min(stageW * 0.84, areaH * 0.88 * 1.57, 980))
    readonly property real cassetteX: (stageW - cassetteW) / 2 + (showPanel ? 24 : 0)

    // ---- the cassette ------------------------------------------------------------------------
    CassetteTape {
        x: cp.cassetteX
        y: cp.topSpace + (cp.areaH - height) / 2
        width: cp.cassetteW
        rotation: -1.5
        active: cp.active
        progress: cp.progress
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        HoverHandler { cursorShape: cp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (cp.s.hasTrack) player.togglePlay() }
    }

    // ---- the right-hand side: lyrics, the track list or the deck's equalizer ---------------------
    // all three take the same place beside the cassette
    // (an inline component cannot see `cp`, so each use places itself)
    component Side: Item {
        property bool open
        visible: opacity > 0
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
    readonly property rect sideRect: Qt.rect(width * 0.6, topSpace + 6, width * 0.4 - 48, areaH - 12)

    // lyrics on a ruled paper card, the sung line marked with a highlighter
    Side {
        open: cp.showPanel && cp.panel === "lyrics"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        LyricsPaper { anchors.fill: parent }
    }

    // the queue as a mixtape's handwritten track list
    Side {
        open: cp.showPanel && cp.panel === "queue"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        TracklistPaper { anchors.fill: parent }
    }

    // the equalizer as a hi-fi tape deck's front panel
    Side {
        open: cp.showPanel && cp.panel === "equalizer"
        x: cp.sideRect.x; y: cp.sideRect.y; width: cp.sideRect.width; height: cp.sideRect.height
        DeckEqualizer {
            anchors.fill: parent
            active: cp.active && parent.visible
        }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: cp.bottomSpace
        onCloseRequested: cp.closeRequested()
    }
}
