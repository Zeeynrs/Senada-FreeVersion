import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Slim top row: back, bloom logo, quick search, update status and profile.
Item {
    id: top
    property bool canGoBack: false
    property string currentKey
    signal back()

    implicitHeight: 68

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 12

        IconButton {
            visible: top.canGoBack
            iconName: "back"
            tip: "Kembali (Alt+←)"
            onClicked: top.back()
        }

        // logo: a mint bloom with the wordmark
        AbstractButton {
            id: logo
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            implicitWidth: logoRow.implicitWidth
            implicitHeight: 40
            onClicked: Nav.go("home")
            contentItem: Row {
                id: logoRow
                spacing: 10
                Item {
                    width: 30; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    Scallop {
                        anchors.fill: parent
                        lobes: 9; depth: 0.13
                        color: Theme.mint
                        rotation: logo.hovered ? 20 : 0
                        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                    }
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.centerIn: parent
                        color: Theme.fuchsia
                    }
                }
                Label {
                    text: "senada"
                    font.pixelSize: 24
                    font.weight: Font.Black
                    font.letterSpacing: -0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        // quick search pill (opens the search page)
        AbstractButton {
            id: searchPill
            visible: top.currentKey !== "search"
            Layout.preferredWidth: Math.min(380, top.width * 0.32)
            implicitHeight: 42
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            onClicked: Nav.go("search")
            background: Rectangle {
                radius: height / 2
                color: searchPill.hovered ? Theme.glassHover : Theme.glass
                border.color: Theme.glassBorder
            }
            contentItem: RowLayout {
                spacing: 10
                Icon { Layout.leftMargin: 14; glyph: "search"; size: 18; color: Theme.dim }
                Label {
                    Layout.fillWidth: true
                    text: "Cari lagu, artis, atau tempel link…"
                    color: Theme.faint
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Label {
                    Layout.rightMargin: 14
                    text: "Ctrl F"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
        }

        Item { Layout.fillWidth: true }

        // update: a mint chip when a new commit is waiting, otherwise a quiet check button
        Chip {
            visible: updater.updateAvailable
            checked: true
            iconName: "download"
            text: updater.updating ? "Memperbarui…" : "Update (" + updater.commitsBehind + ")"
            enabled: !updater.updating
            onClicked: updater.applyUpdate()
            ToolTip.visible: hovered
            ToolTip.text: updater.remoteMessage
            ToolTip.delay: 400
        }

        // profile chip -> settings
        AbstractButton {
            id: profile
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            implicitHeight: 42
            implicitWidth: profRow.implicitWidth + 20
            onClicked: Nav.go("settings")
            background: Rectangle {
                radius: height / 2
                color: profile.hovered || top.currentKey === "settings" ? Theme.glassHover : "transparent"
            }
            contentItem: Item {
                Row {
                    id: profRow
                    anchors.centerIn: parent
                    spacing: 10
                    Item {
                        width: 32; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        Scallop { anchors.fill: parent; lobes: 10; depth: 0.08; color: Theme.alpha(Theme.fuchsia, 0.9) }
                        Label {
                            anchors.centerIn: parent
                            text: (library.me.name || "?").charAt(0).toUpperCase()
                            font.pixelSize: 14
                            font.weight: Font.Black
                            color: "#2a0614"
                        }
                    }
                    Label {
                        text: library.me.name || ""
                        visible: top.width > 1000
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            ToolTip.visible: hovered
            ToolTip.text: "Profil & pengaturan (Ctrl+,)"
            ToolTip.delay: 600
        }
    }
}
