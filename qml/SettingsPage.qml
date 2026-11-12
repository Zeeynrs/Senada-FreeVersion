import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "settings"

    component Section: Rectangle {
        default property alias content: inner.data
        property string title
        Layout.fillWidth: true
        Layout.maximumWidth: 760
        implicitHeight: inner.implicitHeight + 48
        radius: 16
        color: "transparent"
        border.color: Theme.line
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            Label { text: parent.parent.title; font.pixelSize: 16; font.weight: Font.Bold }
        }
    }
    component SettingRow: RowLayout {
        property string label
        property string hint
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: parent.parent.label; font.pixelSize: 14 }
            Label {
                visible: text !== ""
                Layout.fillWidth: true
                text: parent.parent.hint
                color: Theme.dim
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    Flickable {
        id: flick
        SmoothScroll { flickable: flick }
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        ColumnLayout {
            id: col
            x: 28
            y: 24
            width: flick.width - 56
            spacing: 16

            Label { text: "Pengaturan"; font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }

            Section {
                title: "Tema"
                SettingRow {
                    label: "Mode warna"
                    hint: "Ikuti sistem memakai tema terang/gelap dari Windows, KDE, atau GNOME. Warna utama otomatis putih di tema gelap dan hitam di tema terang."
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { key: "system", label: "Ikuti sistem" },
                                { key: "dark", label: "Gelap" },
                                { key: "light", label: "Terang" }
                            ]
                            Chip {
                                text: modelData.label
                                checked: session.themeMode === modelData.key
                                onClicked: session.themeMode = modelData.key
                            }
                        }
                    }
                }
                SettingRow {
                    label: "Efek kaca"
                    hint: session.glassMode === "desktop"
                          ? "Jendela tembus pandang. Blur di belakangnya dibuat sistem: acrylic di Windows 11, blur Hyprland, atau efek blur KDE. Tanpa compositor, latarnya bisa jadi hitam."
                          : session.glassMode === "cover"
                          ? "Panel tembus pandang di atas sampul lagu yang diburamkan. Jalan di semua sistem."
                          : "Panel tidak tembus pandang."
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { key: "off", label: "Mati" },
                                { key: "cover", label: "Sampul album" },
                                { key: "desktop", label: "Transparan" }
                            ]
                            Chip {
                                text: modelData.label
                                checked: session.glassMode === modelData.key
                                onClicked: session.glassMode = modelData.key
                            }
                        }
                    }
                }
                SettingRow {
                    visible: session.glassMode !== "off"
                    label: "Ketebalan kaca"
                    hint: "Geser ke kiri supaya lebih tembus pandang, ke kanan supaya lebih pekat."
                    NSlider {
                        Layout.preferredWidth: 200
                        from: 0.3; to: 0.9
                        value: session.glassOpacity
                        onMoved: session.glassOpacity = value
                    }
                    Label {
                        Layout.preferredWidth: 40
                        text: Math.round(session.glassOpacity * 100) + "%"
                        color: Theme.dim
                        font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Section {
                title: "Profil & Library"
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.dim
                    font.pixelSize: 13
                    text: "Senada tidak butuh akun. Musik diambil dari YouTube Music; lagu disukai, playlist, dan riwayat disimpan di perangkat ini (" + session.libraryPath + ")."
                }
                SettingRow {
                    label: "Nama tampilan"
                    hint: "Dipakai untuk sapaan di Beranda."
                    NTextField {
                        Layout.preferredWidth: 220
                        text: session.displayName
                        onEditingFinished: session.displayName = text
                    }
                }
                SettingRow {
                    label: "Impor dari Spotify"
                    hint: "Tempel link playlist atau album publik Spotify. Tanpa login; seluruh isi playlist ikut diimpor."
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    NTextField {
                        id: importField
                        Layout.fillWidth: true
                        placeholderText: "https://open.spotify.com/playlist/…"
                        onAccepted: if (text.trim()) { library.importSpotify(text.trim()); text = "" }
                    }
                    NButton {
                        text: "Impor"
                        iconName: "download"
                        enabled: importField.text.trim().length > 0
                        onClicked: { library.importSpotify(importField.text.trim()); importField.text = "" }
                    }
                }
            }

            Section {
                title: "Pembaruan Aplikasi (GitHub)"
                SettingRow {
                    label: "Status"
                    hint: "Commit saat ini: " + updater.currentHash + (updater.currentMessage ? " — " + updater.currentMessage : "")
                          + " • Diperiksa: " + updater.lastChecked
                    Rectangle {
                        implicitWidth: 10; implicitHeight: 10; radius: 5
                        color: updater.updating || updater.checking ? Theme.warn
                             : updater.updateAvailable ? Theme.warn : Theme.ok
                    }
                    Label {
                        text: updater.statusText
                        color: updater.updateAvailable ? Theme.text : Theme.dim
                        font.pixelSize: 14
                        font.weight: updater.updateAvailable ? Font.DemiBold : Font.Normal
                    }
                }
                Rectangle {
                    visible: updater.updateAvailable && updater.changelog !== ""
                    Layout.fillWidth: true
                    implicitHeight: changelogLabel.implicitHeight + 24
                    radius: 10
                    color: Theme.subtle
                    border.width: 1
                    border.color: Theme.line
                    Label {
                        id: changelogLabel
                        anchors.fill: parent
                        anchors.margins: 12
                        text: updater.changelog
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.text
                        wrapMode: Text.WordWrap
                    }
                }
                RowLayout {
                    spacing: 10
                    NButton {
                        text: updater.checking ? "Memeriksa…" : "Periksa Pembaruan"
                        iconName: "refresh"
                        enabled: !updater.checking && !updater.updating
                        onClicked: updater.check(false)
                    }
                    NButton {
                        text: updater.updating ? "Memperbarui…" : (updater.updateAvailable ? "Perbarui & Mulai Ulang" : "Sinkronkan Ulang")
                        iconName: "download"
                        primary: updater.updateAvailable
                        enabled: !updater.updating && !updater.checking
                        onClicked: updater.applyUpdate()
                    }
                }
            }

            Section {
                title: "Mesin Audio & Streaming (MPV)"
                SettingRow {
                    label: "Status Mesin"
                    hint: "Pemutar audio lokal bebas iklan & tanpa syarat Spotify Premium"
                    Rectangle {
                        implicitWidth: 10; implicitHeight: 10; radius: 5
                        color: Theme.ok
                    }
                    Label { text: "Aktif (Lokal / MPV)"; color: Theme.dim; font.pixelSize: 14 }
                }
                SettingRow {
                    label: "Nama perangkat"
                    hint: "Nama tampilan perangkat audio lokal ini."
                    NTextField {
                        Layout.preferredWidth: 220
                        text: session.deviceName
                        onEditingFinished: if (text.trim()) session.deviceName = text.trim()
                    }
                }
                SettingRow {
                    label: "Kualitas audio"
                    hint: "Kualitas streaming audio YouTube Music."
                    ComboBox {
                        id: bitrateBox
                        Layout.preferredWidth: 200
                        model: ["Otomatis (Terbaik)", "Tinggi (160 kbps Opus)", "Sedang (128 kbps)"]
                        displayText: currentText
                        background: Rectangle {
                            implicitHeight: 38
                            radius: 10
                            color: bitrateBox.hovered ? Theme.hover : "transparent"
                            border.color: Theme.line
                        }
                        contentItem: Label {
                            leftPadding: 18
                            text: bitrateBox.displayText
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                        popup.background: Rectangle { color: Theme.surface2; radius: 10; border.color: Theme.line }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.dim
                    font.pixelSize: 12
                    text: "Senada memutar musik tanpa memerlukan Spotify Premium dan tanpa iklan menggunakan backend lokal MPV & YouTube Music resolver."
                }
            }

            Section {
                title: "Tampilan"
                SettingRow {
                    label: "Visualizer"
                    hint: visualizer.available ? "Spektrum lingkaran di sekeliling cover pada tampilan penuh (memakai cava)."
                                               : "Spektrum lingkaran di tampilan penuh (pasang cava untuk deteksi audio langsung)."
                    Switch {
                        checked: session.visualizerEnabled
                        onToggled: session.visualizerEnabled = checked
                    }
                }
            }

            Section {
                title: "Pintasan keyboard"
                GridLayout {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 6
                    Repeater {
                        model: [
                            "Spasi", "Putar / jeda",
                            "Ctrl + → / ←", "Lagu berikutnya / sebelumnya",
                            "Ctrl + ↑ / ↓", "Volume naik / turun",
                            "Ctrl + F", "Cari",
                            "Ctrl + L", "Tampilan penuh + lirik",
                            "Alt + ← / Esc", "Kembali / tutup tampilan penuh",
                            "Alt + →", "Maju",
                            "Ctrl + B", "Tampilkan / sembunyikan sidebar",
                            "Ctrl + ,", "Pengaturan"
                        ]
                        Label {
                            text: modelData
                            font.family: index % 2 === 0 ? Theme.mono : Theme.font
                            font.pixelSize: 13
                            color: index % 2 === 0 ? Theme.text : Theme.dim
                        }
                    }
                }
            }
        }
    }
}
