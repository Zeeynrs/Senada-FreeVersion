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
        radius: 20
        color: Theme.alpha(Theme.text, 0.04)
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
        contentHeight: col.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        ColumnLayout {
            id: col
            x: 32
            y: 52
            width: flick.width - 64
            spacing: 18

            Label { text: "Pengaturan"; font.pixelSize: 36; font.weight: Font.Black }

            Section {
                title: "Akun Spotify"
                RowLayout {
                    spacing: 14
                    Cover {
                        Layout.preferredWidth: 48; Layout.preferredHeight: 48
                        round: true
                        source: library.me.image || ""
                        fallbackIcon: "speaker"
                    }
                    Label { Layout.fillWidth: true; text: session.isGuest ? "Mode Tamu (Tanpa Akun)" : (library.me.name || "…"); font.pixelSize: 16; font.weight: Font.DemiBold }
                    NButton { text: session.isGuest ? "Hubungkan Akun" : "Keluar"; onClicked: session.logout() }
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
                             : updater.updateAvailable ? Theme.accent : "#7ee08f"
                    }
                    Label {
                        text: updater.statusText
                        color: updater.updateAvailable ? Theme.accent : Theme.dim
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
                    border.color: Theme.alpha(Theme.accent, 0.25)
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
                        color: "#7ee08f"
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
                            color: index % 2 === 0 ? Theme.accent : Theme.dim
                        }
                    }
                }
            }
        }
    }
}
