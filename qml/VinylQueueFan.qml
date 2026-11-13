import QtQuick
import QtQuick.Controls

// The queue of the turntable full view, fanned out around the record like the lyrics: each
// spoke is a song with its cover as a small record label; the next song is level with the
// record's centre. Scroll to turn the fan, click a song to play it.
// Placed inside VinylPlayer's lyrics area, which gives the geometry.
Item {
    id: fan
    property real ox            // record centre
    property real oy
    property real r0            // spokes start here
    property real lineWidth
    property real upLimit: 30   // degrees above which the tonearm is in the way
    property real downLimit: 62

    readonly property var queue: player.queue
    readonly property real rowH: 50
    readonly property real step: rowH + 16
    readonly property real lastPos: Math.max(0, queue.length - 1) * step
    property real scroll: 0
    readonly property real focusPos: Math.max(0, Math.min(lastPos, scroll))
    property real shownPos: focusPos
    Behavior on shownPos { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    function scrollBy(px) { scroll = Math.max(0, Math.min(lastPos, scroll + px)) }
    function degAt(pos) { return (pos - shownPos) / r0 * 180 / Math.PI }
    function fadeAt(deg) { return Math.max(0, Math.min(1, (deg < 0 ? upLimit + deg : downLimit - deg) / 14)) }
    Component.onCompleted: player.refreshQueue()
    onQueueChanged: scroll = Math.min(scroll, lastPos)

    // heading, one spoke above the first song
    Item {
        readonly property real deg: fan.degAt(-fan.step * 0.9)
        x: fan.ox
        y: fan.oy
        rotation: deg
        opacity: fan.fadeAt(deg)
        visible: opacity > 0
        Label {
            x: fan.r0
            y: -height / 2
            text: I18n.t("UP NEXT") + (fan.queue.length ? "  ·  " + fan.queue.length : "")
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 2.4
        }
    }

    Repeater {
        model: fan.queue
        Item {
            id: spoke
            required property var modelData
            required property int index
            readonly property real deg: fan.degAt(index * fan.step)
            readonly property real fade: fan.fadeAt(deg)
            x: fan.ox
            y: fan.oy
            rotation: deg
            visible: fade > 0

            Item {
                id: row
                x: fan.r0
                y: -height / 2
                width: Math.min(fan.lineWidth, content.implicitWidth + 16)
                height: fan.rowH
                opacity: spoke.fade * (spoke.index === 0 ? 1 : hover.hovered ? 0.95 : 0.62)
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Rectangle {  // hover
                    anchors.fill: parent
                    anchors.leftMargin: -6
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, hover.hovered ? 0.1 : 0)
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Row {
                    id: content
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    // the cover as a small record: black ring around the label
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fan.rowH - 4
                        height: width
                        radius: width / 2
                        color: "#0b0b0d"
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Cover {
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: width
                            round: true
                            simple: true
                            source: spoke.modelData.imageSmall || ""
                        }
                        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: "#d8d8d8" }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Label {
                            width: Math.min(implicitWidth, fan.lineWidth - fan.rowH - 30)
                            text: spoke.modelData.name || ""
                            color: "#ffffff"
                            font.pixelSize: spoke.index === 0 ? 20 : 18
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Label {
                            width: Math.min(implicitWidth, fan.lineWidth - fan.rowH - 30)
                            text: (spoke.modelData.artists || "") + (spoke.modelData.durationMs ? "  ·  " + Theme.fmt(spoke.modelData.durationMs) : "")
                            color: Qt.rgba(1, 1, 1, 0.6)
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: player.skip(spoke.index + 1) }
                ToolTip.visible: hover.hovered
                ToolTip.delay: 600
                ToolTip.text: I18n.t("Play")
            }
        }
    }

    Label {
        x: fan.ox + fan.r0
        y: fan.oy - height / 2
        visible: fan.queue.length === 0
        text: I18n.t("The queue is empty")
        color: Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: 20
        font.weight: Font.Bold
    }
}
