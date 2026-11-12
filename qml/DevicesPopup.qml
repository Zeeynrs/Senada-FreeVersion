import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: p
    width: 340
    padding: 14
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: player.refreshDevices()

    function deviceIcon(type) {
        if (type === "smartphone") return "smartphone"
        if (type === "computer") return "computer"
        return "speaker"
    }

    background: Rectangle {
        color: Theme.surface2
        radius: 22
        border.color: Theme.line
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }

    contentItem: ColumnLayout {
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: I18n.t("Play on a device")
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            IconButton { iconName: "refresh"; size: 18; tip: I18n.t("Reload"); onClicked: player.refreshDevices() }
        }

        Repeater {
            model: player.devices
            AbstractButton {
                id: d
                Layout.fillWidth: true
                implicitHeight: 54
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                enabled: !modelData.restricted
                onClicked: { player.transfer(modelData.id); p.close() }
                background: Rectangle {
                    radius: 12
                    color: modelData.active ? Theme.hover : d.hovered ? Theme.subtle : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12
                    Icon {
                        Layout.leftMargin: 10
                        glyph: p.deviceIcon(modelData.type)
                        size: 24
                        color: modelData.active ? Theme.text : Theme.dim
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        Label {
                            text: modelData.active ? I18n.t("Now playing") : modelData.local ? I18n.t("This computer") : modelData.type
                            font.pixelSize: 12
                            color: Theme.dim
                        }
                    }
                }
            }
        }

        Label {
            visible: player.devices.length === 0
            Layout.fillWidth: true
            Layout.margins: 8
            wrapMode: Text.WordWrap
            color: Theme.dim
            font.pixelSize: 13
            text: I18n.t("No devices yet. Wait for the local device (MPV) to be ready.")
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.text, 0.08); Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Rectangle {
                implicitWidth: 8; implicitHeight: 8; radius: 4
                color: "#7ee08f"
            }
            Label {
                Layout.fillWidth: true
                text: I18n.t("Local device “{name}”: ready (MPV)", { name: session.deviceName })
                font.pixelSize: 12
                color: Theme.dim
                elide: Text.ElideRight
            }
        }
    }
}
