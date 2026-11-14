import QtQuick

// A small drawing of the mini player in one style, for the cards in Settings → Appearance
// (see MiniPlayer.qml): classic, wave, lyrics, glass.
Item {
    id: ip
    property string style: "classic"
    property bool live: false          // move the sound bars (the hovered card)
    readonly property color warm: "#ff8a5c"
    readonly property real ph: Math.min(height, 34)
    readonly property real pw: Math.min(width, ph * 5.4)

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: ip.pw
        height: ip.ph
        radius: height / 2
        color: "#0b0b0c"
        border.width: 1
        border.color: ip.style === "glass" ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
        gradient: ip.style === "glass" ? glass : null
        clip: true
        Gradient {
            id: glass
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#8a3a52" }
            GradientStop { position: 0.5; color: "#4a2a3c" }
            GradientStop { position: 1; color: "#26303f" }
        }

        // cover
        Rectangle {
            x: pill.height * 0.16
            anchors.verticalCenter: parent.verticalCenter
            width: pill.height * 0.68
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: ip.warm }
                GradientStop { position: 1; color: "#c2416b" }
            }
        }
        // title and the line under it
        Column {
            x: pill.height * 0.98
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Rectangle {
                width: pill.width * (ip.style === "lyrics" ? 0.2 : 0.3)
                height: ip.style === "lyrics" ? 2.5 : 3.5
                radius: 1.5
                color: ip.style === "lyrics" ? Qt.rgba(1, 1, 1, 0.45) : "#ffffff"
            }
            Rectangle {
                width: pill.width * (ip.style === "lyrics" ? 0.36 : 0.2)
                height: ip.style === "lyrics" ? 3.5 : 2.5
                radius: 1.5
                color: ip.style === "lyrics" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
            }
        }
        // right side: the time and a ring, sound bars, or a plain play mark
        Row {
            anchors.right: parent.right
            anchors.rightMargin: pill.height * 0.3
            anchors.verticalCenter: parent.verticalCenter
            spacing: pill.height * 0.22
            Rectangle {  // the time
                visible: ip.style === "classic" || ip.style === "glass"
                anchors.verticalCenter: parent.verticalCenter
                width: pill.width * 0.1; height: 2.5; radius: 1.25
                color: Qt.rgba(1, 1, 1, 0.5)
            }
            Row {  // sound bars
                visible: ip.style === "wave"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: [0.5, 0.9, 0.65, 1.0, 0.45]
                    Rectangle {
                        required property var modelData
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2.5
                        height: pill.height * 0.5 * (ip.live ? 0.35 + 0.65 * Math.abs(Math.sin(beat.t * (2 + index) + index)) : modelData)
                        radius: 1.25
                        color: ip.warm
                    }
                }
            }
            Rectangle {  // play / pause, in a ring that fills up (not in the lyrics style)
                anchors.verticalCenter: parent.verticalCenter
                width: pill.height * 0.56
                height: width
                radius: width / 2
                color: "transparent"
                border.width: ip.style === "lyrics" ? 0 : 1.5
                border.color: Qt.rgba(1, 1, 1, 0.3)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.32; height: width * 1.2
                    color: "#ffffff"
                    radius: 1
                }
            }
        }
        // lyrics: the progress line along the bottom
        Rectangle {
            visible: ip.style === "lyrics"
            x: pill.height / 2
            y: pill.height - 4
            width: pill.width - pill.height
            height: 1.5
            color: Qt.rgba(1, 1, 1, 0.15)
            Rectangle { width: parent.width * 0.45; height: parent.height; color: ip.warm }
        }
    }

    FrameAnimation {
        id: beat
        property real t: 0
        running: ip.live && ip.style === "wave"
        onTriggered: t += frameTime
    }
}
