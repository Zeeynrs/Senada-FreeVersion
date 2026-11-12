import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: sb
    property int fontSize: 12
    readonly property var s: player.state
    spacing: 10

    Label {
        text: Theme.fmt(seek.pressed ? seek.value : player.position)
        opacity: 0.65
        font.pixelSize: sb.fontSize
        font.features: { "tnum": 1 }
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
    }
    NSlider {
        id: seek
        Layout.fillWidth: true
        from: 0
        to: Math.max(1, sb.s.durationMs || 0)
        enabled: !!sb.s.hasTrack
        Binding on value {
            value: player.position
            when: !seek.pressed
            restoreMode: Binding.RestoreNone
        }
        onPressedChanged: if (!pressed) player.seek(value)
    }
    Label {
        text: Theme.fmt(sb.s.durationMs)
        opacity: 0.65
        font.pixelSize: sb.fontSize
        font.features: { "tnum": 1 }
        Layout.preferredWidth: 40
    }
}
