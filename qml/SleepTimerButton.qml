import QtQuick
import QtQuick.Controls

// Moon in the player bar: the music stops after a while, or when this song ends (senada/sleep.py).
// Lit while the timer runs; hovering it says how long is left.
IconButton {
    id: sb
    readonly property var timer: player.sleep
    readonly property bool running: timer.mode !== "off"
    property real now: Date.now()

    function minutesText(m) {
        return m < 60 ? I18n.t("{n} min", { n: m })
             : m % 60 === 0 ? I18n.t("{n} h", { n: m / 60 })
             : I18n.t("{h} h {m} min", { h: Math.floor(m / 60), m: m % 60 })
    }
    readonly property int minutesLeft: Math.max(1, Math.ceil((timer.endsAt - now) / 60000))

    iconName: "sleep"
    size: 18
    tint: Theme.dim
    active: running
    tip: timer.mode === "track" ? I18n.t("Sleep timer: stops after this song")
       : timer.mode === "time" ? I18n.t("Sleep timer: {time} left", { time: minutesText(minutesLeft) })
       : I18n.t("Sleep timer")
    onClicked: {
        now = Date.now()
        menu.popup(sb, sb.width - menu.implicitWidth, -menu.implicitHeight - 10)
    }

    Timer {
        running: sb.timer.mode === "time"
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: sb.now = Date.now()
    }

    NMenu {
        id: menu
        MenuItem {
            enabled: false
            text: sb.timer.mode === "time" ? I18n.t("Stops in {time}", { time: sb.minutesText(sb.minutesLeft) })
                : sb.timer.mode === "track" ? I18n.t("Stops after this song")
                : I18n.t("Stop the music after…")
        }
        Instantiator {
            model: sb.timer.choices
            delegate: MenuItem {
                required property var modelData
                text: "     " + sb.minutesText(modelData)
                onTriggered: sb.timer.start(modelData)
            }
            onObjectAdded: (index, object) => menu.insertItem(index + 1, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
        MenuItem {
            text: (sb.timer.mode === "track" ? "✓  " : "     ") + I18n.t("End of this song")
            enabled: player.state.hasTrack
            onTriggered: sb.timer.stopAfterTrack()
        }
        MenuItem {
            text: "     " + I18n.t("Turn off")
            enabled: sb.running
            onTriggered: sb.timer.cancel()
        }
    }
}
