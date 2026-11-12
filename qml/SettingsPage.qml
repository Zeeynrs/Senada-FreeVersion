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

            Label { text: I18n.t("Settings"); font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }

            Section {
                title: I18n.t("Language")
                SettingRow {
                    label: I18n.t("Interface language")
                    hint: I18n.t("Changes right away. Home shelves from YouTube Music follow it too.")
                    Row {
                        spacing: 6
                        Repeater {
                            // each language is named in its own language
                            model: [
                                { key: "en", label: "English" },
                                { key: "id", label: "Bahasa Indonesia" }
                            ]
                            Chip {
                                text: modelData.label
                                checked: session.language === modelData.key
                                onClicked: session.language = modelData.key
                            }
                        }
                    }
                }
            }

            Section {
                title: I18n.t("Theme")
                SettingRow {
                    label: I18n.t("Color mode")
                    hint: I18n.t("Follow system uses the light/dark theme of Windows, KDE or GNOME. The main color is white in the dark theme and black in the light theme.")
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { key: "system", label: I18n.t("Follow system") },
                                { key: "dark", label: I18n.t("Dark") },
                                { key: "light", label: I18n.t("Light") }
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
                    label: I18n.t("Glass effect")
                    hint: session.glassMode === "desktop"
                          ? I18n.t("See-through window. The blur behind it comes from the system: acrylic on Windows 11, blur on Windows 10, Hyprland blur or the KDE blur effect. Without a compositor the background can turn black.")
                          : session.glassMode === "cover"
                          ? I18n.t("See-through panels over the blurred cover of the song. Works on every system.")
                          : I18n.t("Panels are not see-through.")
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { key: "off", label: I18n.t("Off") },
                                { key: "cover", label: I18n.t("Album cover") },
                                { key: "desktop", label: I18n.t("Transparent") }
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
                    label: I18n.t("Glass thickness")
                    hint: I18n.t("Slide left for more see-through, right for more solid.")
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
                title: I18n.t("Profile & Library")
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.dim
                    font.pixelSize: 13
                    text: I18n.t("Senada needs no account. Music comes from YouTube Music; liked songs, playlists and history are stored on this device ({path}).", { path: session.libraryPath })
                }
                SettingRow {
                    label: I18n.t("Display name")
                    hint: I18n.t("Used for the greeting on Home.")
                    NTextField {
                        Layout.preferredWidth: 220
                        text: session.displayName
                        onEditingFinished: session.displayName = text
                    }
                }
                SettingRow {
                    label: I18n.t("Import from Spotify")
                    hint: I18n.t("Paste a link to a public Spotify playlist or album. No login; the whole playlist is imported.")
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
                        text: I18n.t("Import")
                        iconName: "download"
                        enabled: importField.text.trim().length > 0
                        onClicked: { library.importSpotify(importField.text.trim()); importField.text = "" }
                    }
                }
            }

            Section {
                title: I18n.t("App updates (GitHub)")
                SettingRow {
                    label: I18n.t("Status")
                    hint: updater.currentLabel + " • " + I18n.t("Checked: {time}", { time: updater.lastChecked })
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
                        text: updater.checking ? I18n.t("Checking…") : I18n.t("Check for updates")
                        iconName: "refresh"
                        enabled: !updater.checking && !updater.updating
                        onClicked: updater.check(false)
                    }
                    NButton {
                        visible: !updater.releaseMode || updater.updateAvailable || updater.updating
                        text: updater.updating ? I18n.t("Updating…") : (updater.updateAvailable ? I18n.t("Update & restart") : I18n.t("Sync again"))
                        iconName: "download"
                        primary: updater.updateAvailable
                        enabled: !updater.updating && !updater.checking
                        onClicked: updater.applyUpdate()
                    }
                }
            }

            Section {
                title: I18n.t("Audio engine & streaming (MPV)")
                SettingRow {
                    label: I18n.t("Engine status")
                    hint: I18n.t("Local audio player, ad-free and without Spotify Premium")
                    Rectangle {
                        implicitWidth: 10; implicitHeight: 10; radius: 5
                        color: Theme.ok
                    }
                    Label { text: I18n.t("Active (local / MPV)"); color: Theme.dim; font.pixelSize: 14 }
                }
                SettingRow {
                    label: I18n.t("Device name")
                    hint: I18n.t("Display name of this local audio device.")
                    NTextField {
                        Layout.preferredWidth: 220
                        text: session.deviceName
                        onEditingFinished: if (text.trim()) session.deviceName = text.trim()
                    }
                }
                SettingRow {
                    label: I18n.t("Audio quality")
                    hint: I18n.t("Streaming quality of YouTube Music audio.")
                    ComboBox {
                        id: bitrateBox
                        Layout.preferredWidth: 200
                        model: [I18n.t("Automatic (best)"), I18n.t("High (160 kbps Opus)"), I18n.t("Medium (128 kbps)")]
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
                    text: I18n.t("Senada plays music without Spotify Premium and without ads, using a local MPV backend and a YouTube Music resolver.")
                }
            }

            Section {
                title: I18n.t("Display")
                SettingRow {
                    label: I18n.t("Visualizer")
                    hint: visualizer.available ? I18n.t("Circular spectrum around the cover in full view (uses cava).")
                                               : I18n.t("Circular spectrum in full view (install cava to follow the audio live).")
                    Switch {
                        checked: session.visualizerEnabled
                        onToggled: session.visualizerEnabled = checked
                    }
                }
            }

            Section {
                title: I18n.t("Keyboard shortcuts")
                GridLayout {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 6
                    Repeater {
                        model: [
                            I18n.t("Space"), I18n.t("Play / pause"),
                            "Ctrl + → / ←", I18n.t("Next / previous song"),
                            "Ctrl + ↑ / ↓", I18n.t("Volume up / down"),
                            "Ctrl + F", I18n.t("Search"),
                            "Ctrl + L", I18n.t("Full view + lyrics"),
                            "Alt + ← / Esc", I18n.t("Back / close full view"),
                            "Alt + →", I18n.t("Forward"),
                            "Ctrl + B", I18n.t("Show / hide sidebar"),
                            "Ctrl + ,", I18n.t("Open / close Settings")
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
