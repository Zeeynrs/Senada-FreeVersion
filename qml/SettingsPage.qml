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
        radius: 30
        color: Theme.glass
        border.color: Theme.glassBorder
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            Label { text: parent.parent.title; font.pixelSize: 18; font.weight: Font.Bold }
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
            Label { text: parent.parent.label; font.pixelSize: 15 }
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
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        ColumnLayout {
            id: col
            x: 36
            y: 4
            width: flick.width - 64
            spacing: 18

            Label { text: "Pengaturan"; font.pixelSize: 44; font.weight: Font.Black; font.letterSpacing: -1.2 }

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
                    hint: "Tempel link playlist atau album publik Spotify. Tanpa login; maks. ±100 lagu per playlist."
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
                        color: updater.updating || updater.checking ? "#ffd36e"
                             : updater.updateAvailable ? Theme.fuchsia : Theme.mint
                    }
                    Label {
                        text: updater.statusText
                        color: updater.updateAvailable ? Theme.mint : Theme.dim
                        font.pixelSize: 14
                        font.weight: updater.updateAvailable ? Font.DemiBold : Font.Normal
                    }
                }
                Rectangle {
                    visible: updater.updateAvailable && updater.changelog !== ""
                    Layout.fillWidth: true
                    implicitHeight: changelogLabel.implicitHeight + 24
                    radius: 12
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.alpha(Theme.mint, 0.25)
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
                        color: Theme.mint
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
                            implicitHeight: 40
                            radius: 20
                            color: Theme.alpha(Theme.text, bitrateBox.hovered ? 0.11 : 0.07)
                        }
                        contentItem: Label {
                            leftPadding: 18
                            text: bitrateBox.displayText
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                        popup.background: Rectangle { color: Theme.surface3; radius: 12 }
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
                            "Ctrl + ,", "Pengaturan"
                        ]
                        Label {
                            text: modelData
                            font.family: index % 2 === 0 ? Theme.mono : Theme.font
                            font.pixelSize: 13
                            color: index % 2 === 0 ? Theme.mint : Theme.dim
                        }
                    }
                }
            }
        }
    }
}
