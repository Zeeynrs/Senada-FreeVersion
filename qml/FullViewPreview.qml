import QtQuick
import QtQuick.Controls

// A small drawing of the full view in one style, for the cards in Settings → Appearance:
//   visualizer  round cover in a ring of spectrum bars, the lyrics as lines beside it
//   vinyl       a record on the left edge with its tonearm, the lyrics fanned out around it
//   cassette    a cassette with its two reels, the lyrics on a ruled paper card beside it
//   poster      the cover large, the title upright beside it, a headline and a pull quote
//   radio       a wooden valve radio with its grille, glowing dial and knobs
//   walkman     a portable cassette player with its keys, the lyrics card beside it
// Always dark, like the full view itself (it sits on the blurred cover art).
Item {
    id: pv
    property string style: "visualizer"
    readonly property real w: width
    readonly property real h: height
    readonly property color warm1: "#ff8a5c"
    readonly property color warm2: "#c2416b"
    clip: true

    // blurred album art behind everything
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#3b1f2e" }
            GradientStop { position: 0.55; color: "#1d1a2b" }
            GradientStop { position: 1; color: "#10141c" }
        }
    }
    // a lyric line: the sung one bright, the others faint
    component Line: Rectangle {
        property bool sung: false
        height: sung ? 5 : 4
        radius: height / 2
        color: sung ? "#ffffff" : Qt.rgba(1, 1, 1, 0.32)
    }

    // ---- visualizer ---------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: ["vinyl", "cassette", "poster", "radio", "walkman"].indexOf(pv.style) < 0
        readonly property real cx: pv.w * 0.3
        readonly property real cy: pv.h * 0.4
        readonly property real r: pv.h * 0.19

        Repeater {  // spectrum ring
            model: 40
            Item {
                required property int index
                x: parent.cx
                y: parent.cy
                rotation: index * 9
                Rectangle {
                    x: -1
                    width: 2
                    radius: 1
                    height: pv.h * (0.035 + 0.045 * Math.abs(Math.sin(index * 1.7)))
                    y: -(parent.parent.r + 3 + height)
                    color: Qt.rgba(0.62, 0.84, 1, 0.85)
                }
            }
        }
        Rectangle {  // cover
            x: parent.cx - width / 2
            y: parent.cy - height / 2
            width: parent.r * 2
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: pv.warm1 }
                GradientStop { position: 1; color: pv.warm2 }
            }
        }
        Column {  // title, seek bar, controls
            x: parent.cx - width / 2
            y: pv.h * 0.7
            width: pv.w * 0.24
            spacing: 4
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.6; height: 5; radius: 2.5; color: "#ffffff" }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.38; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.45) }
            Rectangle { width: parent.width; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.3)
                Rectangle { width: parent.width * 0.45; height: parent.height; radius: 1; color: "#ffffff" } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 9; height: 9; radius: 4.5; color: "#ffffff" }
        }
        Column {  // lyrics
            x: pv.w * 0.56
            y: pv.h * 0.2
            spacing: pv.h * 0.075
            Repeater {
                model: [0.55, 0.4, 0.62, 0.34, 0.5, 0.44]
                Line { required property var modelData; required property int index
                       width: pv.w * 0.38 * modelData; sung: index === 2 }
            }
        }
    }

    // ---- vinyl --------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: pv.style === "vinyl"
        readonly property real rad: pv.h * 0.4
        readonly property real cx: rad * 0.36
        readonly property real cy: pv.h * 0.42

        Repeater {  // lyrics fanned out around the record
            model: [-24, -16, -8, 0, 8, 16, 24]
            Item {
                required property var modelData
                required property int index
                x: parent.cx
                y: parent.cy
                rotation: modelData
                Line {
                    x: parent.parent.rad + pv.h * 0.09
                    y: -height / 2
                    width: pv.w * [0.2, 0.16, 0.24, 0.27, 0.22, 0.15, 0.19][index]
                    sung: modelData === 0
                    opacity: 1 - Math.abs(modelData) / 40
                }
            }
        }
        Rectangle {  // record
            x: parent.cx - parent.rad
            y: parent.cy - parent.rad
            width: parent.rad * 2
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#24242a" }
                GradientStop { position: 1; color: "#08080a" }
            }
            Repeater {  // grooves
                model: [0.88, 0.76, 0.64]
                Rectangle {
                    required property var modelData
                    anchors.centerIn: parent
                    width: parent.width * modelData
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                }
            }
            Rectangle {  // label
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: pv.warm1 }
                    GradientStop { position: 1; color: pv.warm2 }
                }
            }
            Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: "#e6e6e6" }
        }
        Item {  // tonearm
            x: parent.cx + parent.rad * 0.98
            y: parent.cy - parent.rad * 0.86
            Rectangle { x: -width / 2; y: -height / 2; width: parent.parent.rad * 0.24; height: width; radius: width / 2; color: "#2c2c31" }
            Item {
                rotation: 104
                Rectangle { x: -4; y: -1.25; width: parent.parent.parent.rad * 1.0; height: 2.5; radius: 1.25; color: "#d8d8d8" }
                Rectangle { x: parent.parent.parent.rad * 0.94; y: -3.5; width: parent.parent.parent.rad * 0.2; height: 7; radius: 1.5; color: "#3a3a40" }
            }
            Rectangle { x: -3; y: -3; width: 6; height: 6; radius: 3; color: "#f0f0f0" }
        }
        Row {  // title on the left, controls in the middle of the bottom strip
            x: pv.w * 0.05
            y: pv.h * 0.86
            spacing: pv.w * 0.18
            Column {
                spacing: 3
                Rectangle { width: pv.w * 0.16; height: 4; radius: 2; color: "#ffffff" }
                Rectangle { width: pv.w * 0.1; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.45) }
            }
            Column {
                spacing: 3
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    Repeater {
                        model: [4, 4, 8, 4, 4]
                        Rectangle { required property var modelData; anchors.verticalCenter: parent.verticalCenter
                                    width: modelData; height: modelData; radius: modelData / 2
                                    color: modelData > 4 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6) }
                    }
                }
                Rectangle { width: pv.w * 0.26; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.3)
                    Rectangle { width: parent.width * 0.6; height: parent.height; radius: 1; color: "#ffffff" } }
            }
        }
    }

    // ---- cassette -----------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: pv.style === "cassette"
        readonly property real u: pv.w * 0.5 / 100   // a 100 x 64 mm cassette, half the card wide

        Rectangle {  // shell
            id: shell
            x: pv.w * 0.05
            y: pv.h * 0.17
            width: parent.u * 100
            height: parent.u * 64
            radius: parent.u * 4
            rotation: -2
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a3a42" }
                GradientStop { position: 1; color: "#1a1a1f" }
            }
            readonly property real u: parent.u
            Rectangle {  // label
                x: 6 * shell.u; y: 5 * shell.u
                width: 88 * shell.u; height: 39 * shell.u
                radius: 2 * shell.u
                color: "#efe7d4"
                Rectangle { y: 14.5 * shell.u; width: parent.width; height: 2.6 * shell.u; color: pv.warm1 }
                Rectangle { y: 17.4 * shell.u; width: parent.width; height: 1.2 * shell.u; color: pv.warm2 }
                Rectangle { x: 13 * shell.u; y: 4 * shell.u; width: 40 * shell.u; height: 3.4 * shell.u; radius: height / 2; color: "#3a3640" }
                Rectangle { x: 13 * shell.u; y: 9.5 * shell.u; width: 24 * shell.u; height: 2.2 * shell.u; radius: height / 2; color: Qt.rgba(0.23, 0.21, 0.25, 0.55) }
            }
            Rectangle {  // window with the reels
                x: 19 * shell.u; y: 20 * shell.u
                width: 62 * shell.u; height: 18 * shell.u
                radius: height / 2
                color: "#0d0d10"
                clip: true
                Repeater {
                    model: [[9.75, 15.5], [52.25, 9.5]]   // centre x in the window, tape radius
                    Item {
                        required property var modelData
                        x: modelData[0] * shell.u
                        y: 9 * shell.u
                        Rectangle { x: -width / 2; y: -height / 2; width: parent.modelData[1] * 2 * shell.u; height: width; radius: width / 2; color: "#5a3d2c" }
                        Rectangle { x: -width / 2; y: -height / 2; width: 10 * shell.u; height: width; radius: width / 2; color: "#ecebe6"
                            Rectangle { anchors.centerIn: parent; width: parent.width * 0.6; height: width; radius: width / 2; color: "#0d0d10" } }
                    }
                }
            }
            Rectangle {  // the raised strip at the bottom
                x: 21 * shell.u; y: 48 * shell.u
                width: 58 * shell.u; height: 16 * shell.u
                color: Qt.rgba(1, 1, 1, 0.06)
            }
        }
        Rectangle {  // lyrics card
            x: pv.w * 0.63
            y: pv.h * 0.1
            width: pv.w * 0.32
            height: pv.h * 0.66
            radius: 3
            rotation: 2
            color: "#f4efe2"
            Rectangle { x: 8; width: 1; height: parent.height; color: Qt.rgba(0.85, 0.3, 0.3, 0.5) }
            Column {
                x: 13
                y: 8
                spacing: 6
                Repeater {
                    model: [0.7, 0.5, 0.78, 0.6, 0.45]
                    Item {
                        required property var modelData
                        required property int index
                        width: (pv.w * 0.32 - 20) * modelData
                        height: 5
                        Rectangle { visible: index === 2; x: -2; y: -1.5; width: parent.width + 4; height: 8; radius: 2; color: Qt.rgba(1, 0.86, 0.3, 0.85) }
                        Rectangle { width: parent.width; height: 3; y: 1; radius: 1.5; color: index === 2 ? "#26262e" : Qt.rgba(0.15, 0.15, 0.19, 0.45) }
                    }
                }
            }
        }
        Row {  // bottom strip: title on the left, controls in the middle
            x: pv.w * 0.05
            y: pv.h * 0.86
            spacing: pv.w * 0.18
            Column {
                spacing: 3
                Rectangle { width: pv.w * 0.16; height: 4; radius: 2; color: "#ffffff" }
                Rectangle { width: pv.w * 0.1; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.45) }
            }
            Column {
                spacing: 3
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    Repeater {
                        model: [4, 4, 8, 4, 4]
                        Rectangle { required property var modelData; anchors.verticalCenter: parent.verticalCenter
                                    width: modelData; height: modelData; radius: modelData / 2
                                    color: modelData > 4 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6) }
                    }
                }
                Rectangle { width: pv.w * 0.26; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.3)
                    Rectangle { width: parent.width * 0.4; height: parent.height; radius: 1; color: "#ffffff" } }
            }
        }
    }

    // the strip of controls along the bottom, shared by the drawings below
    // (an inline component cannot see `pv`: it gets the size)
    component BottomStrip: Row {
        id: strip
        property real w
        property real h
        x: strip.w * 0.05
        y: strip.h * 0.86
        spacing: strip.w * 0.18
        Column {
            spacing: 3
            Rectangle { width: strip.w * 0.16; height: 4; radius: 2; color: "#ffffff" }
            Rectangle { width: strip.w * 0.1; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.45) }
        }
        Column {
            spacing: 3
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: [4, 4, 8, 4, 4]
                    Rectangle { required property var modelData; anchors.verticalCenter: parent.verticalCenter
                                width: modelData; height: modelData; radius: modelData / 2
                                color: modelData > 4 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6) }
                }
            }
            Rectangle { width: strip.w * 0.26; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.3)
                Rectangle { width: parent.width * 0.5; height: parent.height; radius: 1; color: "#ffffff" } }
        }
    }

    // ---- poster ---------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: pv.style === "poster"
        Rectangle {  // the cover's colour field
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#5a2236" }
                GradientStop { position: 0.6; color: "#141218" }
            }
        }
        Rectangle {  // the cover
            x: pv.w * 0.05
            y: pv.h * 0.1
            width: pv.h * 0.66
            height: width
            gradient: Gradient {
                GradientStop { position: 0; color: pv.warm1 }
                GradientStop { position: 1; color: pv.warm2 }
            }
            Rectangle { width: parent.width; height: 5; color: Qt.rgba(0, 0, 0, 0.4) }
        }
        Label {  // the title, upright
            x: pv.w * 0.05 + pv.h * 0.66 + 4
            y: pv.h * 0.1 + pv.h * 0.66
            transformOrigin: Item.TopLeft
            rotation: -90
            text: "SENADA"
            color: "#ffffff"
            font.pixelSize: pv.h * 0.13
            font.weight: Font.Black
        }
        Column {  // headline, rule, pull quote
            x: pv.w * 0.52
            y: pv.h * 0.12
            spacing: 5
            Rectangle { width: 14; height: 2; color: pv.warm1 }
            Rectangle { width: pv.w * 0.3; height: 7; radius: 2; color: "#ffffff" }
            Rectangle { width: pv.w * 0.18; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.5) }
            Rectangle { width: pv.w * 0.42; height: 1; color: Qt.rgba(1, 1, 1, 0.3) }
            Item { width: 1; height: 2 }
            Row {
                spacing: 4
                Label { text: "“"; color: pv.warm1; font.pixelSize: pv.h * 0.18; font.weight: Font.Bold; height: pv.h * 0.12 }
                Column {
                    spacing: 4
                    topPadding: 3
                    Rectangle { width: pv.w * 0.32; height: 5; radius: 2; color: "#ffffff" }
                    Rectangle { width: pv.w * 0.22; height: 5; radius: 2; color: "#ffffff" }
                    Rectangle { width: pv.w * 0.26; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.45) }
                }
            }
        }
        BottomStrip { w: pv.w; h: pv.h }
    }

    // ---- radio ----------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: pv.style === "radio"
        Rectangle {  // cabinet
            id: cabinet
            x: (pv.w - width) / 2
            y: pv.h * 0.1
            width: pv.w * 0.62
            height: width * 0.56
            radius: width * 0.05
            gradient: Gradient {
                GradientStop { position: 0; color: "#7a4a29" }
                GradientStop { position: 1; color: "#3f2414" }
            }
            Rectangle {  // grille
                x: parent.width * 0.06; y: parent.height * 0.1
                width: parent.width * 0.44; height: parent.height * 0.8
                radius: 3
                color: "#cdb98f"
                Repeater {
                    model: 5
                    Rectangle { required property int index
                                x: (index + 1) * parent.width / 6 - 1.5; width: 3; height: parent.height; color: "#5e3720" }
                }
            }
            Rectangle {  // glowing dial with the needle
                x: parent.width * 0.55; y: parent.height * 0.1
                width: parent.width * 0.39; height: parent.height * 0.42
                radius: 3
                gradient: Gradient {
                    GradientStop { position: 0; color: "#ffe2a3" }
                    GradientStop { position: 1; color: "#e9a443" }
                }
                Rectangle { x: 4; y: 5; width: parent.width * 0.6; height: 3; radius: 1.5; color: "#3a2208" }
                Row {
                    x: 4; y: parent.height - 7
                    spacing: (parent.width - 8 - 10 * 1) / 9
                    Repeater { model: 10; Rectangle { width: 1; height: 4; color: "#4a2a0e" } }
                }
                Rectangle { x: parent.width * 0.45; y: 2; width: 2; height: parent.height - 4; color: "#c4271b" }
            }
            Repeater {  // knobs and the magic eye
                model: [[0.6, 0.62], [0.82, 0.62]]
                Rectangle { required property var modelData
                            x: cabinet.width * modelData[0]; y: cabinet.height * modelData[1]
                            width: cabinet.width * 0.12; height: width; radius: width / 2
                            color: "#2b1d14"; border.color: "#140c07"
                            Rectangle { x: parent.width / 2 - 1; y: 2; width: 2; height: parent.height * 0.35; color: "#f3e2c0" } }
            }
            Rectangle { x: cabinet.width * 0.745; y: cabinet.height * 0.66; width: cabinet.width * 0.05; height: width; radius: width / 2; color: "#47e486" }
        }
        BottomStrip { w: pv.w; h: pv.h }
    }

    // ---- walkman --------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: pv.style === "walkman"
        Item {
            id: wm
            x: pv.w * 0.06
            y: pv.h * 0.16
            width: pv.w * 0.46
            height: width * 0.74
            rotation: -3
            Row {  // keys
                x: parent.width * 0.1; y: -5
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle { required property int index
                                width: wm.width * 0.13; height: 8; radius: 1.5
                                y: index === 1 ? 2 : 0
                                color: index === 1 ? "#7d838c" : "#b9bec6" }
                }
            }
            Rectangle {  // body
                anchors.fill: parent
                radius: parent.width * 0.06
                gradient: Gradient {
                    GradientStop { position: 0; color: "#aab4c2" }
                    GradientStop { position: 1; color: "#5f6a79" }
                }
            }
            Rectangle {  // window with the cassette
                x: parent.width * 0.06; y: parent.height * 0.14
                width: parent.width * 0.88; height: parent.height * 0.72
                radius: 3
                color: "#15171b"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.86; height: parent.height * 0.82
                    radius: 3
                    color: "#2a2a30"
                    Rectangle { x: parent.width * 0.06; y: parent.height * 0.08; width: parent.width * 0.88; height: parent.height * 0.6; radius: 2; color: "#efe7d4"
                        Rectangle { y: parent.height * 0.4; width: parent.width; height: 3; color: pv.warm1 }
                        Rectangle { x: parent.width * 0.2; y: parent.height * 0.55; width: parent.width * 0.6; height: parent.height * 0.35; radius: height / 2; color: "#0d0d10"
                            Rectangle { x: parent.width * 0.1; anchors.verticalCenter: parent.verticalCenter; width: parent.height * 0.8; height: width; radius: width / 2; color: "#ecebe6" }
                            Rectangle { x: parent.width * 0.9 - width; anchors.verticalCenter: parent.verticalCenter; width: parent.height * 0.8; height: width; radius: width / 2; color: "#ecebe6" } }
                    }
                }
            }
            Rectangle { x: parent.width - 2; y: parent.height * 0.3; width: 5; height: parent.height * 0.36; radius: 2; color: "#2a2d33" }  // volume wheel
        }
        Rectangle {  // lyrics card
            x: pv.w * 0.63
            y: pv.h * 0.1
            width: pv.w * 0.32
            height: pv.h * 0.66
            radius: 3
            rotation: 2
            color: "#f4efe2"
            Rectangle { x: 8; width: 1; height: parent.height; color: Qt.rgba(0.85, 0.3, 0.3, 0.5) }
            Column {
                x: 13; y: 8; spacing: 6
                Repeater {
                    model: [0.7, 0.5, 0.78, 0.6, 0.45]
                    Item {
                        required property var modelData
                        required property int index
                        width: (pv.w * 0.32 - 20) * modelData; height: 5
                        Rectangle { visible: index === 2; x: -2; y: -1.5; width: parent.width + 4; height: 8; radius: 2; color: Qt.rgba(1, 0.86, 0.3, 0.85) }
                        Rectangle { width: parent.width; height: 3; y: 1; radius: 1.5; color: index === 2 ? "#26262e" : Qt.rgba(0.15, 0.15, 0.19, 0.45) }
                    }
                }
            }
        }
        BottomStrip { w: pv.w; h: pv.h }
    }
}
