import QtQuick
import QtQuick.Controls

// Slider in the app's style. The bar itself is a SeekTrack, so the seek bars can take the
// style picked in Settings (`trackStyle`); everything else keeps the plain line.
Slider {
    id: c
    property color fill: Theme.accented ? Theme.primary : palette.windowText
    property string trackStyle: "line"
    property string seed: ""        // the song, for the "bars" style
    property bool playing: false    // the "wave" style ripples while playing
    readonly property bool engaged: hovered || pressed

    implicitHeight: 20
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: SeekTrack {
        x: c.leftPadding
        y: c.topPadding
        width: c.availableWidth
        height: c.availableHeight
        trackStyle: c.trackStyle
        progress: c.visualPosition
        fill: c.fill
        rest: Theme.alpha(c.palette.windowText, 0.16)
        knob: c.palette.windowText
        engaged: c.engaged
        playing: c.playing
        seed: c.seed
    }
    // the knob is drawn by the track; this only gives the slider something to grab
    handle: Item {
        x: c.leftPadding + c.visualPosition * (c.availableWidth - width)
        y: c.topPadding + c.availableHeight / 2 - height / 2
        width: 14
        height: 14
    }
}
