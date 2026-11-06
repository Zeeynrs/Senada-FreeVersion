import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// First-run login view: supports Guest Mode (no login), Developer Client ID, and sp_dc cookie.
Item {
    id: root

    property string mode: "guest" // "guest" | "oauth" | "cookie"

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, card.implicitHeight + 80)
        clip: true

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(640, parent.width - 48)
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
                            text: "Pemutar musik bebas iklan & tanpa syarat Spotify Premium"
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
                        text: "✨ Mode Tamu (Tanpa Login)"
                        primary: root.mode === "guest"
                        onClicked: root.mode = "guest"
                    }
                    NButton {
                        text: "Developer Client ID"
                        primary: root.mode === "oauth"
                        onClicked: root.mode = "oauth"
                    }
                    NButton {
                        text: "Cookie sp_dc"
                        primary: root.mode === "cookie"
                        onClicked: root.mode = "cookie"
                    }
                }

                // --- GUEST MODE (NO LOGIN REQUIRED) ---
                ColumnLayout {
                    visible: root.mode === "guest"
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: guestInfoCol.implicitHeight + 24
                        radius: 16
                        color: Theme.alpha(Theme.accent, 0.08)
                        border.color: Theme.alpha(Theme.accent, 0.22)
                        border.width: 1

                        ColumnLayout {
                            id: guestInfoCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Label {
                                text: "Masuk Langsung Tanpa Akun & Tanpa Ribet"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: "• Bebas dari syarat Spotify Premium & tidak perlu membuat Developer App.\n• Langsung cari & putar jutaan lagu via pencarian YouTube Music / MPV.\n• Bisa memutar tautan lagu & playlist publik Spotify.\n• (Opsional: Anda bisa menghubungkan akun Spotify kapan saja nanti di menu Pengaturan)."
                                font.pixelSize: 13
                                color: Theme.text
                            }
                        }
                    }

                    NButton {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        primary: true
                        text: "Mulai Mendengarkan Sekarang (Mode Tamu)"
                        onClicked: session.enterGuestMode()
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
                        color: Theme.text
                        font.pixelSize: 14
                        text: "<b>Metode Resmi & Permanen:</b> Hubungkan akun Spotify Anda agar lagu yang disukai (*Liked Songs*) & playlist pribadi tersinkronisasi."
                        textFormat: Text.StyledText
                    }

                    Repeater {
                        model: [
                            "Buka <b>developer.spotify.com/dashboard</b> lalu klik <b>Create app</b>.",
                            "Isi <b>Redirect URI</b> dengan alamat di bawah ini, centang <b>Web API</b>, lalu simpan.",
                            "⚠️ <b>PENTING (Khusus Akun Free):</b> Buka menu <b>User Management</b> di dashboard app Anda, masukkan <b>alamat email akun Spotify Anda</b> agar tidak ditolak Spotify.",
                            "Salin <b>Client ID</b> (32 karakter) lalu tempel di kolom bawah:"
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

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
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
                                font.pixelSize: 12
                                color: Theme.accent
                            }
                            NButton { text: "Salin"; onClicked: session.copy(session.redirectUri) }
                        }
                    }

                    NTextField {
                        id: clientField
                        Layout.fillWidth: true
                        placeholderText: "Client ID Spotify (32 karakter)"
                        text: session.clientId || "e37ebd248fee46b8b99f79be6cec7ee6"
                        font.family: Theme.mono
                        onAccepted: session.login(text.trim())
                    }

                    NButton {
                        Layout.fillWidth: true
                        primary: true
                        enabled: !session.busy && clientField.text.trim().length > 0
                        text: session.busy ? "Menunggu otorisasi di browser…" : "Masuk dengan Client ID"
                        onClicked: session.login(clientField.text.trim())
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
                        text: "<b>Metode Cookie Sesi:</b> Menggunakan cookie login dari web player Spotify."
                        textFormat: Text.StyledText
                    }

                    Repeater {
                        model: [
                            "Buka <b>open.spotify.com</b> di browser dan login dengan akun Spotify Anda.",
                            "Tekan <b>F12</b> (Inspect Element) > buka tab <b>Application</b> (Chrome) atau <b>Storage</b> (Firefox).",
                            "Di menu kiri, buka <b>Cookies</b> > klik <b>https://open.spotify.com</b>.",
                            "Cari cookie bernama <b>sp_dc</b>, salin nilainya lalu tempel di bawah:"
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
                        placeholderText: "Tempel nilai cookie sp_dc di sini..."
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
