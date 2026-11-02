import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, card.implicitHeight + 80)
        clip: true

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(580, parent.width - 48)
            height: col.implicitHeight + 64
            radius: 28
            color: Theme.surface
            border.color: Theme.alpha(Theme.text, 0.06)

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 32
                spacing: 16

                RowLayout {
                    spacing: 16
                    Image {
                        source: Qt.resolvedUrl("../data/senada.svg")
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        sourceSize: Qt.size(108, 108)
                    }
                    ColumnLayout {
                        spacing: 2
                        Label { text: "Selamat datang di Senada"; font.pixelSize: 26; font.weight: Font.Black }
                        Label {
                            text: "Pemutar Spotify gratis & bebas iklan untuk Linux desktop"
                            color: Theme.dim
                            font.pixelSize: 13
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.text
                    font.pixelSize: 14
                    text: "Masuk dengan akun Spotify Anda. Musik diputar secara lokal melalui backend MPV tanpa iklan dan tanpa syarat Spotify Premium."
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 14
                    color: Theme.bg
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 6
                        Label {
                            Layout.fillWidth: true
                            text: "Redirect URI: " + session.redirectUri
                            font.family: Theme.mono
                            font.pixelSize: 12
                            color: Theme.accent
                        }
                        NButton { text: "Salin"; onClicked: session.copy(session.redirectUri) }
                    }
                }

                NTextField {
                    id: clientField
                    Layout.fillWidth: true
                    placeholderText: "Client ID Spotify"
                    text: session.clientId || "e37ebd248fee46b8b99f79be6cec7ee6"
                    font.family: Theme.mono
                    onAccepted: session.login(text.trim())
                }

                NButton {
                    Layout.fillWidth: true
                    primary: true
                    enabled: !session.busy && clientField.text.trim().length > 0
                    text: session.busy ? "Menunggu otorisasi di browser…" : "Masuk dengan Spotify"
                    onClicked: session.login(clientField.text.trim())
                }

                Label {
                    Layout.fillWidth: true
                    visible: session.message !== ""
                    text: session.message
                    wrapMode: Text.WordWrap
                    color: session.busy ? Theme.dim : Theme.danger
                    font.pixelSize: 13
                }
            }
        }
    }
}
