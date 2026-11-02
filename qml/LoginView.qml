import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// First-run login view: supports sp_dc cookie (free accounts) and Client ID (developer app).
Item {
    id: root

    property string mode: "cookie" // "cookie" | "oauth"

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, card.implicitHeight + 80)
        clip: true

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(620, parent.width - 48)
            height: col.implicitHeight + 64
            radius: 28
            color: Theme.surface
            border.color: Theme.alpha(Theme.text, 0.06)

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 32
                spacing: 14

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

                // Mode switch
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8

                    NButton {
                        text: "Login via Cookie sp_dc (Gratis)"
                        primary: root.mode === "cookie"
                        onClicked: root.mode = "cookie"
                    }
                    NButton {
                        text: "Developer Client ID"
                        primary: root.mode === "oauth"
                        onClicked: root.mode = "oauth"
                    }
                }

                // --- COOKIE LOGIN MODE ---
                ColumnLayout {
                    visible: root.mode === "cookie"
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        font.pixelSize: 14
                        text: "<b>Metode Direkomendasikan:</b> Tidak memerlukan akun Spotify Premium dan tidak perlu membuat Developer App."
                        textFormat: Text.StyledText
                    }

                    Repeater {
                        model: [
                            "Buka <b>open.spotify.com</b> di browser dan login dengan akun Spotify-mu.",
                            "Tekan <b>F12</b> (Inspect Element) > pilih tab <b>Application</b> (Chrome) atau <b>Storage</b> (Firefox).",
                            "Di menu kiri, buka <b>Cookies</b> > klik <b>https://open.spotify.com</b>.",
                            "Cari cookie bernama <b>sp_dc</b>, salin isinya lalu tempel di bawah ini:"
                        ]
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 24; implicitHeight: 24; radius: 12
                                color: Theme.alpha(Theme.accent, 0.18)
                                Label { anchors.centerIn: parent; text: index + 1; color: Theme.accent; font.weight: Font.Bold; font.pixelSize: 12 }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                textFormat: Text.StyledText
                                wrapMode: Text.WordWrap
                                font.pixelSize: 13
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        NButton { text: "Buka Spotify Web"; onClicked: session.openUrl("https://open.spotify.com") }
                        Item { Layout.fillWidth: true }
                    }

                    NTextField {
                        id: cookieField
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        placeholderText: "Tempel cookie sp_dc di sini (panjang ~150-250 karakter)..."
                        font.family: Theme.mono
                        onAccepted: session.loginWithCookie(text)
                    }

                    NButton {
                        Layout.fillWidth: true
                        primary: true
                        enabled: !session.busy && cookieField.text.trim().length > 10
                        text: session.busy ? "Memverifikasi akun Spotify…" : "Masuk dengan Cookie"
                        onClicked: session.loginWithCookie(cookieField.text)
                    }
                }

                // --- DEVELOPER OAUTH MODE ---
                ColumnLayout {
                    visible: root.mode === "oauth"
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Theme.dim
                        font.pixelSize: 13
                        text: "Gunakan metode ini jika Anda memiliki Spotify Developer App yang terdaftar."
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
                                text: session.redirectUri
                                font.family: Theme.mono
                                font.pixelSize: 13
                                color: Theme.accent
                            }
                            NButton { text: "Salin"; onClicked: session.copy(session.redirectUri) }
                        }
                    }

                    NTextField {
                        id: clientField
                        Layout.fillWidth: true
                        placeholderText: "Client ID (32 karakter)"
                        text: session.clientId
                        font.family: Theme.mono
                        onAccepted: session.login(text)
                    }

                    NButton {
                        Layout.fillWidth: true
                        primary: true
                        enabled: !session.busy
                        text: session.busy ? "Menunggu browser…" : "Masuk dengan Client ID"
                        onClicked: session.login(clientField.text)
                    }
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
