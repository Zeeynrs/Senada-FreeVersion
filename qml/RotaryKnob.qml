import QtQuick
import QtQuick.Controls

// A ribbed bakelite knob that turns from -135° (`from`) to +135° (`to`). Drag up / down or
// scroll to turn it, double-click to go back to `resetValue`. Used by the radio full view.
Item {
    id: knob
    property real value: 0
    property real from: -1
    property real to: 1
    property real resetValue: 0
    property real stepSize: (to - from) / 40
    property string label
    property string valueText
    property color body: "#2b1d14"
    property color rim: "#140c07"
    property color mark: "#f3e2c0"
    property color labelColor: "#f3e2c0"
    property bool interactive: true
    signal moved(real value)

    readonly property real frac: (value - from) / Math.max(1e-9, to - from)
    readonly property real angle: -135 + 270 * Math.max(0, Math.min(1, frac))
    readonly property real size: Math.min(width, height - (label ? 34 : 0))
    implicitWidth: 72
    implicitHeight: 72 + (label ? 34 : 0)

    function set(v) {
        const c = Math.max(from, Math.min(to, v))
        if (c !== value)
            moved(c)
    }

    Item {
        id: dial
        width: knob.size
        height: knob.size
        anchors.horizontalCenter: parent.horizontalCenter

        // scale ticks around the knob
        Repeater {
            model: 11
            Rectangle {
                required property int index
                x: dial.width / 2 - width / 2
                y: -2
                width: 2
                height: 5
                radius: 1
                color: Qt.rgba(knob.labelColor.r, knob.labelColor.g, knob.labelColor.b, index === 5 ? 0.8 : 0.4)
                transform: Rotation { origin.x: 1; origin.y: dial.height / 2 + 2; angle: -135 + index * 27 }
            }
        }
        // shadow
        Rectangle {
            x: dial.width * 0.12 + 3
            y: dial.height * 0.12 + 5
            width: dial.width * 0.76
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        // body, turning with the value
        Item {
            x: dial.width * 0.12
            y: dial.height * 0.12
            width: dial.width * 0.76
            height: width
            rotation: knob.angle
            Behavior on rotation { enabled: !drag.pressed; NumberAnimation { duration: 140 } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: knob.rim
            }
            Repeater {  // ribs
                model: 28
                Rectangle {
                    required property int index
                    x: parent.width / 2 - width / 2
                    y: 0
                    width: Math.max(2, parent.width * 0.05)
                    height: parent.height * 0.12
                    color: Qt.lighter(knob.body, 1.25)
                    transform: Rotation { origin.x: width / 2; origin.y: parent.height / 2; angle: index * 360 / 28 }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.8
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(knob.body, 1.6) }
                    GradientStop { position: 1; color: knob.body }
                }
                Rectangle {  // indicator
                    x: parent.width / 2 - width / 2
                    y: parent.height * 0.06
                    width: Math.max(2, parent.width * 0.07)
                    height: parent.height * 0.3
                    radius: width / 2
                    color: knob.mark
                }
            }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            enabled: knob.interactive
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            property real startY: 0
            property real startValue: 0
            onPressed: (mouse) => { startY = mouse.y; startValue = knob.value }
            onPositionChanged: (mouse) => {
                if (pressed)
                    knob.set(startValue + (startY - mouse.y) / 160 * (knob.to - knob.from))
            }
            onDoubleClicked: knob.set(knob.resetValue)
            onWheel: (wheel) => knob.set(knob.value + (wheel.angleDelta.y > 0 ? knob.stepSize : -knob.stepSize))
        }
    }
    Column {
        visible: !!knob.label
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.height + 6
        spacing: 1
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: knob.label
            color: knob.labelColor
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.4
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!knob.valueText
            text: knob.valueText
            color: Qt.rgba(knob.labelColor.r, knob.labelColor.g, knob.labelColor.b, 0.7)
            font.pixelSize: 10
            font.features: { "tnum": 1 }
        }
    }
}
