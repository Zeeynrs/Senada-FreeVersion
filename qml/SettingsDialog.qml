import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Settings as a dialog over the app: sections (with search) on the left, the chosen
// section on the right. Opened with Nav.go("settings" [, section]) or Ctrl+,
Popup {
    id: dlg
    objectName: "settingsDialog"
    property string section: "appearance"
    property string query: ""

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(1000, parent ? parent.width - 64 : 1000)
    height: Math.min(700, parent ? parent.height - 64 : 700)
    modal: true
    focus: true
    padding: 8
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function openAt(key) {
        if (key && sections.some(s => s.key === key))
            section = key
        searchField.text = ""
        open()
    }

    readonly property color paneLeft: Theme.dark ? "#161616" : "#f1f1f1"
    readonly property color paneRight: Theme.dark ? "#0d0d0d" : "#ffffff"

    // `words` are English labels inside the section, searched in both languages
    readonly property var sections: [
        { group: "Preferences", key: "appearance", icon: "palette", title: "Appearance",
          desc: "Language, theme and the look of the app.",
          words: ["Interface language", "Language", "Theme", "Color mode", "Dark", "Light", "Follow system",
                  "Accent color", "Accent strength", "Color", "Logo",
                  "Glass effect", "Glass thickness", "Transparent", "Album cover", "Visualizer",
                  "Full view style", "Vinyl record", "Turntable", "Full view",
                  "Mini player", "Dynamic island", "Minimize"] },
        { group: "Preferences", key: "audio", icon: "speaker", title: "Audio",
          desc: "Audio engine and streaming quality.",
          words: ["Engine status", "Device name", "Audio quality", "MPV", "Audio engine & streaming (MPV)"] },
        { group: "Preferences", key: "lyrics", icon: "lyrics", title: "Lyrics",
          desc: "Where synced lyrics come from.",
          words: ["Lyrics source", "Automatic", "LRCLIB", "YouTube Music", "NetEase", "Synced lyrics"] },
        { group: "Preferences", key: "shortcuts", icon: "keyboard", title: "Shortcuts",
          desc: "Keyboard shortcuts that work anywhere in the app.",
          words: ["Keyboard shortcuts", "Play / pause", "Search", "Volume up / down", "Next / previous song", "Mini player"] },
        { group: "Preferences", key: "profile", icon: "person", title: "Profile & Library",
          desc: "Your name and the music kept on this device.",
          words: ["Offline songs", "Download", "Downloads", "Offline", "Open folder", "Display name", "Import a playlist", "Import from Spotify", "Spotify", "YouTube Music", "YouTube", "Import", "Playlist"] },
        { group: "App", key: "whatsnew", icon: "new", title: "What's new",
          desc: "What changed in each version, and which version is on this device.",
          words: ["Changelog", "Log", "Release", "Version", "On this device", "Version history"] },
        { group: "App", key: "updates", icon: "refresh", title: "Updates",
          desc: "New versions of Senada from GitHub.",
          words: ["App updates (GitHub)", "Check for updates", "Update & restart", "GitHub", "Version"] },
        { group: "App", key: "about", icon: "info", title: "About",
          desc: "About Senada.",
          words: ["Version", "License", "Senada"] }
    ]
    readonly property var groups: ["Preferences", "App"]

    function matches(s) {
        const q = query.trim().toLowerCase()
        if (!q)
            return true
        const words = [s.title, s.desc].concat(s.words)
        return words.some(w => w.toLowerCase().indexOf(q) >= 0 || I18n.t(w).toLowerCase().indexOf(q) >= 0)
    }
    readonly property var shown: sections.filter(s => matches(s))
    readonly property var current: sections.find(s => s.key === section) || sections[0]
    onShownChanged: if (shown.length > 0 && !shown.some(s => s.key === section)) section = shown[0].key
    onSectionChanged: body.contentY = 0

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
            NumberAnimation { property: "scale"; from: 1; to: 0.98; duration: 120 }
        }
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
    background: Rectangle {
        radius: 20
        color: dlg.paneLeft
        border.color: Theme.line
    }

    // ---- building blocks ---------------------------------------------------------------
    // label + hint on the left, controls (the children) on the right
    component SettingRow: RowLayout {
        id: sr
        property string label
        property string hint
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        spacing: 20
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Label { text: sr.label; font.pixelSize: 14; font.weight: Font.DemiBold }
            Label {
                visible: text !== ""
                Layout.fillWidth: true
                text: sr.hint
                color: Theme.dim
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
    // label + hint on top, wide content (the children) below
    component SettingBlock: ColumnLayout {
        id: sb
        default property alias content: sbBody.data
        property string label
        property string hint
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        spacing: 3
        Label { text: sb.label; font.pixelSize: 14; font.weight: Font.DemiBold }
        Label {
            visible: text !== ""
            Layout.fillWidth: true
            text: sb.hint
            color: Theme.dim
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            id: sbBody
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 10
        }
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.line
    }
    component Note: Label {
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        wrapMode: Text.WordWrap
        color: Theme.dim
        font.pixelSize: 13
    }
    component Pill: Rectangle {
        property alias text: pl.text
        implicitWidth: pl.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: Theme.selected
        border.color: Theme.accented ? Theme.alpha(Theme.primary, 0.45) : Theme.line
        Label {
            id: pl
            anchors.centerIn: parent
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Theme.accentInk
        }
    }
    component Bullet: RowLayout {
        property alias text: bl.text
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 7
            implicitWidth: 5; implicitHeight: 5; radius: 2.5
            color: Theme.accented ? Theme.primary : Theme.dim
        }
        Label {
            id: bl
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            lineHeight: 1.15
        }
    }
    component Keycap: Rectangle {
        property alias text: kl.text
        implicitWidth: kl.implicitWidth + 16
        implicitHeight: 26
        radius: 7
        color: Theme.subtle
        border.color: Theme.line
        Label {
            id: kl
            anchors.centerIn: parent
            font.family: Theme.mono
            font.pixelSize: 12
        }
    }

    // a tiny drawing of the app window in one theme, for the theme cards
    component MiniApp: Item {
        id: mini
        property bool darkLook
        readonly property color block: darkLook ? "#2e2e2e" : "#dedede"
        readonly property color bar: darkLook ? "#3a3a3a" : "#cfcfcf"
        Row {
            x: 10; y: 9
            spacing: 4
            Repeater {
                model: ["#ff5f57", "#febc2e", "#28c840"]
                Rectangle { width: 6; height: 6; radius: 3; color: modelData }
            }
        }
        Column {
            x: 10; y: 24
            spacing: 6
            Repeater {
                model: [0.22, 0.17, 0.2]
                Rectangle { width: mini.width * modelData; height: 5; radius: 2.5; color: mini.bar }
            }
        }
        Rectangle {
            x: 10
            y: mini.height - 22
            width: mini.width * 0.22
            height: 12
            radius: 3
            color: mini.block
        }
        Grid {
            x: mini.width * 0.36
            y: 24
            columns: 2
            spacing: 6
            Repeater {
                model: 4
                Rectangle {
                    width: (mini.width * 0.64 - 16) / 2
                    height: (mini.height - 24 - 16) / 2
                    radius: 4
                    color: mini.block
                }
            }
        }
    }

    // one accent colour: the logo in that colour and its name
    component AccentChip: AbstractButton {
        id: ac
        property var accent
        readonly property bool selected: Theme.accentName === accent.key
        implicitHeight: 36
        implicitWidth: acRow.implicitWidth + 22
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: session.accentColor = accent.key
        background: Rectangle {
            radius: 9
            color: ac.selected ? Theme.pressed : ac.hovered ? Theme.hover : "transparent"
            border.width: ac.selected ? 1 : 0
            border.color: Theme.line
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: Item {
            Row {
                id: acRow
                anchors.centerIn: parent
                spacing: 8
                LogoMark {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    colors: Theme.accentColors(ac.accent)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t(ac.accent.label)
                    font.pixelSize: 13
                    font.weight: ac.selected ? Font.Bold : Font.Normal
                    color: ac.selected || ac.hovered ? Theme.text : Theme.dim
                }
            }
        }
    }

    component ThemeCard: AbstractButton {
        id: tc
        property string mode
        property string label
        readonly property bool selected: session.themeMode === mode
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: shot.height + 28
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: session.themeMode = mode

        contentItem: Item {}
        background: Item {
            Rectangle {
                id: shot
                width: parent.width
                height: Math.round(width * 0.5)
                radius: 10
                color: tc.mode === "dark" ? "#1b1b1b" : "#f6f6f6"
                // "system": the right half shows the dark theme
                Rectangle {
                    visible: tc.mode === "system"
                    x: parent.width / 2
                    width: parent.width / 2
                    height: parent.height
                    radius: 10
                    color: "#1b1b1b"
                    Rectangle { width: 10; height: parent.height; color: parent.color }
                }
                Item {
                    width: tc.mode === "system" ? parent.width / 2 : parent.width
                    height: parent.height
                    clip: true
                    MiniApp { width: parent.width; height: parent.height; darkLook: tc.mode === "dark" }
                }
                Item {
                    visible: tc.mode === "system"
                    x: parent.width / 2
                    width: parent.width / 2
                    height: parent.height
                    clip: true
                    MiniApp { width: parent.width; height: parent.height; darkLook: true }
                }
                // frame drawn on top so the halves stay inside it
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.width: tc.selected ? 2 : 1
                    border.color: tc.selected ? Theme.primary : tc.hovered ? Theme.lineStrong : Theme.line
                }
                Rectangle {
                    visible: tc.selected
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: 20; height: 20; radius: 10
                    color: Theme.primary
                    Icon { anchors.centerIn: parent; glyph: "check"; size: 14; color: Theme.primaryText }
                }
            }
            Label {
                anchors.top: shot.bottom
                anchors.topMargin: 8
                text: tc.label
                font.pixelSize: 13
                font.weight: tc.selected ? Font.Bold : Font.Normal
                color: tc.selected || tc.hovered ? Theme.text : Theme.dim
            }
        }
    }

    // a full view style with a small drawing of it, picked like the theme cards
    component ViewStyleCard: AbstractButton {
        id: vc
        property string viewStyle
        property string label
        readonly property bool selected: session.immersiveStyle === viewStyle
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: preview.height + 28
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: session.immersiveStyle = viewStyle

        contentItem: Item {}
        background: Item {
            Item {
                id: preview
                width: parent.width
                height: Math.round(width * 0.5)
                // rounded corners for the drawing
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                FullViewPreview { anchors.fill: parent; style: vc.viewStyle }
            }
            Rectangle {
                id: previewMask
                width: preview.width
                height: preview.height
                radius: 10
                visible: false
                layer.enabled: true
            }
            Rectangle {
                width: preview.width
                height: preview.height
                radius: 10
                color: "transparent"
                border.width: vc.selected ? 2 : 1
                border.color: vc.selected ? Theme.primary : vc.hovered ? Theme.lineStrong : Theme.line
            }
            Rectangle {
                visible: vc.selected
                x: preview.width - width - 8
                y: 8
                width: 20; height: 20; radius: 10
                color: Theme.primary
                Icon { anchors.centerIn: parent; glyph: "check"; size: 14; color: Theme.primaryText }
            }
            Label {
                y: preview.height + 8
                text: vc.label
                font.pixelSize: 13
                font.weight: vc.selected ? Font.Bold : Font.Normal
                color: vc.selected || vc.hovered ? Theme.text : Theme.dim
            }
        }
    }

    contentItem: Item {
        // ---- left: search + sections + profile ------------------------------------------
        ColumnLayout {
            id: left
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: 232
            spacing: 2

            NTextField {
                id: searchField
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                implicitHeight: 38
                iconName: "search"
                placeholderText: I18n.t("Search settings…")
                onTextChanged: dlg.query = text
            }

            Repeater {
                model: dlg.groups
                ColumnLayout {
                    id: grp
                    required property string modelData
                    readonly property var items: dlg.shown.filter(s => s.group === grp.modelData)
                    visible: items.length > 0
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.topMargin: 10
                        Layout.bottomMargin: 4
                        leftPadding: 10
                        text: I18n.t(grp.modelData)
                        color: Theme.faint
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: grp.items
                        AbstractButton {
                            id: entry
                            required property var modelData
                            readonly property bool current: dlg.section === modelData.key
                            Layout.fillWidth: true
                            implicitHeight: 38
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: dlg.section = modelData.key
                            background: Rectangle {
                                radius: 9
                                color: entry.current ? (Theme.accented ? Theme.selected : Theme.pressed) : entry.hovered ? Theme.hover : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Rectangle {
                                    visible: entry.current && Theme.accented
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3; height: 16; radius: 1.5
                                    color: Theme.primary
                                }
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Icon {
                                    Layout.leftMargin: 10
                                    glyph: entry.modelData.icon
                                    size: 18
                                    color: entry.current ? Theme.accentInk : entry.hovered ? Theme.text : Theme.dim
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: I18n.t(entry.modelData.title)
                                    font.pixelSize: 14
                                    font.weight: entry.current ? Font.DemiBold : Font.Normal
                                    color: entry.current ? Theme.accentInk : entry.hovered ? Theme.text : Theme.dim
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Label {
                visible: dlg.shown.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 12
                leftPadding: 10
                rightPadding: 10
                text: I18n.t("No settings match “{q}”.", { q: dlg.query.trim() })
                color: Theme.dim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            // who is listening: name and device, opens the profile section
            AbstractButton {
                id: me
                Layout.fillWidth: true
                implicitHeight: 52
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                onClicked: dlg.section = "profile"
                background: Rectangle {
                    radius: 10
                    color: me.hovered ? Theme.hover : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 10
                    Rectangle {
                        Layout.leftMargin: 8
                        implicitWidth: 34; implicitHeight: 34; radius: 17
                        color: Theme.surface3
                        Label {
                            anchors.centerIn: parent
                            text: (session.displayName || "S").charAt(0).toUpperCase()
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 10; height: 10; radius: 5
                            color: Theme.ok
                            border.width: 2
                            border.color: dlg.paneLeft
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: session.displayName || "Senada"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: session.deviceName
                            color: Theme.dim
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ---- right: the chosen section ---------------------------------------------------
        Rectangle {
            id: right
            anchors.left: left.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 14
            color: dlg.paneRight
            border.color: Theme.line

            ColumnLayout {
                id: head
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 28
                anchors.rightMargin: 64
                anchors.topMargin: 24
                spacing: 4
                Label {
                    text: I18n.t(dlg.current.title)
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                Label {
                    Layout.fillWidth: true
                    text: I18n.t(dlg.current.desc)
                    color: Theme.dim
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            IconButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                iconName: "close"
                size: 18
                tip: I18n.t("Close")
                onClicked: dlg.close()
            }

            Flickable {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: head.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 10
                anchors.bottomMargin: 2
                clip: true
                contentHeight: page.implicitHeight + 24
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: NScrollBar {}
                SmoothScroll { flickable: body }

                Loader {
                    id: page
                    x: 28
                    width: body.width - 56
                    sourceComponent: dlg.section === "audio" ? audioPage
                                   : dlg.section === "lyrics" ? lyricsPage
                                   : dlg.section === "shortcuts" ? shortcutsPage
                                   : dlg.section === "profile" ? profilePage
                                   : dlg.section === "updates" ? updatesPage
                                   : dlg.section === "about" ? aboutPage
                                   : dlg.section === "whatsnew" ? whatsNewPage
                                   : appearancePage
                }
            }
        }
    }

    // ---- sections --------------------------------------------------------------------------
    Component {
        id: appearancePage
        ColumnLayout {
            spacing: 0
            SettingRow {
                label: I18n.t("Interface language")
                hint: I18n.t("Changes right away. Home shelves from YouTube Music follow it too.")
                NCombo {
                    // each language is named in its own language
                    model: [
                        { key: "en", label: "English" },
                        { key: "id", label: "Bahasa Indonesia" }
                    ]
                    value: session.language
                    onPicked: (key) => session.language = key
                }
            }
            Divider {}
            SettingBlock {
                label: I18n.t("Theme")
                hint: I18n.t("Follow system uses the light/dark theme of Windows, KDE or GNOME.")
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ThemeCard { mode: "system"; label: I18n.t("Follow system") }
                    ThemeCard { mode: "light"; label: I18n.t("Light") }
                    ThemeCard { mode: "dark"; label: I18n.t("Dark") }
                }
            }
            Divider {}
            SettingBlock {
                label: I18n.t("Accent color")
                hint: I18n.t("Color of the logo, play buttons, seek bar and other details.")
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Theme.accents
                        AccentChip { required property var modelData; accent: modelData }
                    }
                }
            }
            SettingRow {
                visible: Theme.accented
                Layout.topMargin: 0
                label: I18n.t("Accent strength")
                hint: session.accentStrength === "subtle"
                      ? I18n.t("Only the current song, the open page and the controls take the color.")
                      : I18n.t("Also lights the top of the pages with a soft glow of the color.")
                NCombo {
                    model: [
                        { key: "subtle", label: I18n.t("Subtle") },
                        { key: "vivid", label: I18n.t("Vivid") }
                    ]
                    value: session.accentStrength
                    onPicked: (key) => session.accentStrength = key
                }
            }
            Divider {}
            SettingRow {
                label: I18n.t("Glass effect")
                hint: session.glassMode === "desktop"
                      ? I18n.t("See-through window. The blur behind it comes from the system: acrylic on Windows 11, blur on Windows 10, Hyprland blur or the KDE blur effect. Without a compositor the background can turn black.")
                      : session.glassMode === "cover"
                      ? I18n.t("See-through panels over the blurred cover of the song. Works on every system.")
                      : I18n.t("Panels are not see-through.")
                NCombo {
                    model: [
                        { key: "off", label: I18n.t("Off") },
                        { key: "cover", label: I18n.t("Album cover") },
                        { key: "desktop", label: I18n.t("Transparent") }
                    ]
                    value: session.glassMode
                    onPicked: (key) => session.glassMode = key
                }
            }
            SettingRow {
                visible: session.glassMode !== "off"
                Layout.topMargin: 0
                label: I18n.t("Glass thickness")
                hint: I18n.t("Slide left for more see-through, right for more solid.")
                NSlider {
                    Layout.preferredWidth: 160
                    from: 0.3; to: 0.9
                    value: session.glassOpacity
                    onMoved: session.glassOpacity = value
                }
                Label {
                    Layout.preferredWidth: 36
                    text: Math.round(session.glassOpacity * 100) + "%"
                    color: Theme.dim
                    font.pixelSize: 13
                    font.features: { "tnum": 1 }
                }
            }
            Divider {}
            SettingBlock {
                label: I18n.t("Full view style")
                hint: session.immersiveStyle === "vinyl"
                      ? I18n.t("A spinning record on the left edge with a tonearm that follows the song (drag it to seek); the lyrics fan out around the record.")
                      : I18n.t("The round cover in the middle of a circular visualizer, the lyrics next to it.")
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ViewStyleCard { viewStyle: "visualizer"; label: I18n.t("Visualizer") }
                    ViewStyleCard { viewStyle: "vinyl"; label: I18n.t("Vinyl record") }
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }  // same card size as the theme cards
                }
            }
            SettingRow {
                visible: session.immersiveStyle !== "vinyl"
                Layout.topMargin: 0
                label: I18n.t("Visualizer")
                hint: visualizer.available ? I18n.t("Circular spectrum around the cover in full view (uses cava).")
                                           : I18n.t("Circular spectrum in full view (install cava to follow the audio live).")
                NSwitch {
                    checked: session.visualizerEnabled
                    onToggled: session.visualizerEnabled = checked
                }
            }
            Divider {}
            SettingRow {
                label: I18n.t("Mini player")
                hint: I18n.t("A small player at the top of the screen while Senada is minimized: arrow down for the lyrics. Ctrl+M opens it any time.")
                NSwitch {
                    checked: session.miniPlayer
                    onToggled: session.miniPlayer = checked
                }
            }
        }
    }

    Component {
        id: audioPage
        ColumnLayout {
            spacing: 0
            SettingRow {
                label: I18n.t("Engine status")
                hint: I18n.t("Local audio player, ad-free and without Spotify Premium")
                Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: Theme.ok }
                Label { text: I18n.t("Active (local / MPV)"); color: Theme.dim; font.pixelSize: 13 }
            }
            Divider {}
            SettingRow {
                label: I18n.t("Device name")
                hint: I18n.t("Display name of this local audio device.")
                NTextField {
                    Layout.preferredWidth: 220
                    implicitHeight: 36
                    text: session.deviceName
                    onEditingFinished: if (text.trim()) session.deviceName = text.trim()
                }
            }
            Divider {}
            SettingRow {
                label: I18n.t("Audio quality")
                hint: I18n.t("Streaming quality of YouTube Music audio.")
                NCombo {
                    Layout.preferredWidth: 220
                    model: [
                        { key: "auto", label: I18n.t("Automatic (best)") },
                        { key: "high", label: I18n.t("High (160 kbps Opus)") },
                        { key: "medium", label: I18n.t("Medium (128 kbps)") }
                    ]
                    value: "auto"
                }
            }
            Divider {}
            Note {
                text: I18n.t("Senada plays music without Spotify Premium and without ads, using a local MPV backend and a YouTube Music resolver.")
            }
        }
    }

    Component {
        id: lyricsPage
        ColumnLayout {
            spacing: 0
            SettingRow {
                label: I18n.t("Lyrics source")
                hint: lyrics.source === "auto"
                      ? I18n.t("Tries LRCLIB, YouTube Music and NetEase in turn and shows the first synced lyrics found.")
                      : I18n.t("Only this source is used. If a song has no lyrics there, pick another one here or under the lyrics.")
                NCombo {
                    Layout.preferredWidth: 220
                    model: lyrics.sources.map(s => ({ key: s.key, label: s.key === "auto" ? I18n.t("Automatic") : s.name }))
                    value: lyrics.source
                    onPicked: (key) => lyrics.source = key
                }
            }
            Divider {}
            Note {
                text: I18n.t("LRCLIB is a free, open lyrics database. YouTube Music shows the lyrics of the exact song being played. NetEase Cloud Music has many synced lyrics, also for Asian songs. You can also switch the source for the song that is playing with the button under the lyrics.")
            }
        }
    }

    Component {
        id: shortcutsPage
        ColumnLayout {
            spacing: 0
            Repeater {
                model: [
                    { keys: [I18n.t("Space")], what: I18n.t("Play / pause") },
                    { keys: ["Ctrl", "→ / ←"], what: I18n.t("Next / previous song") },
                    { keys: ["Ctrl", "↑ / ↓"], what: I18n.t("Volume up / down") },
                    { keys: ["Ctrl", "F"], what: I18n.t("Search") },
                    { keys: ["Ctrl", "L"], what: I18n.t("Full view + lyrics") },
                    { keys: ["Alt", "←"], what: I18n.t("Back / close full view") },
                    { keys: ["Alt", "→"], what: I18n.t("Forward") },
                    { keys: ["Ctrl", "B"], what: I18n.t("Show / hide sidebar") },
                    { keys: ["Ctrl", "M"], what: I18n.t("Mini player") },
                    { keys: ["Ctrl", ","], what: I18n.t("Open / close Settings") }
                ]
                ColumnLayout {
                    id: sc
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    Divider { visible: sc.index > 0 }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 11
                        Layout.bottomMargin: 11
                        spacing: 6
                        Label {
                            Layout.fillWidth: true
                            text: sc.modelData.what
                            font.pixelSize: 14
                        }
                        Repeater {
                            model: sc.modelData.keys
                            Keycap { text: modelData }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: profilePage
        ColumnLayout {
            spacing: 0
            SettingRow {
                label: I18n.t("Display name")
                hint: I18n.t("Used for the greeting on Home.")
                NTextField {
                    Layout.preferredWidth: 220
                    implicitHeight: 36
                    text: session.displayName
                    onEditingFinished: session.displayName = text
                }
            }
            Divider {}
            SettingBlock {
                label: I18n.t("Import a playlist")
                hint: I18n.t("Paste a link to a public (or unlisted) playlist or album from Spotify or YouTube Music. No login; the whole playlist is imported.")
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    NTextField {
                        id: importField
                        Layout.fillWidth: true
                        implicitHeight: 38
                        placeholderText: "open.spotify.com/playlist/…  ·  music.youtube.com/playlist?list=…"
                        onAccepted: if (text.trim()) { library.importLink(text.trim()); text = "" }
                    }
                    NButton {
                        text: I18n.t("Import")
                        iconName: "download"
                        enabled: importField.text.trim().length > 0
                        onClicked: { library.importLink(importField.text.trim()); importField.text = "" }
                    }
                }
            }
            Divider {}
            SettingRow {
                label: I18n.t("Offline songs")
                hint: I18n.t("{n} downloaded ({size}), kept in {path}. They play without internet.",
                             { n: downloads.count, size: downloads.sizeText, path: downloads.folderPath })
                NButton {
                    text: I18n.t("Open folder")
                    onClicked: downloads.openFolder()
                }
            }
            Divider {}
            Note {
                text: I18n.t("Senada needs no account. Music comes from YouTube Music; liked songs, playlists and history are stored on this device ({path}).", { path: session.libraryPath })
            }
        }
    }

    Component {
        id: updatesPage
        ColumnLayout {
            spacing: 0
            SettingRow {
                label: I18n.t("Status")
                hint: updater.currentLabel + " • " + I18n.t("Checked: {time}", { time: updater.lastChecked })
                Rectangle {
                    implicitWidth: 8; implicitHeight: 8; radius: 4
                    color: updater.updating || updater.checking || updater.updateAvailable ? Theme.warn : Theme.ok
                }
                Label {
                    text: updater.statusText
                    color: updater.updateAvailable ? Theme.text : Theme.dim
                    font.pixelSize: 13
                    font.weight: updater.updateAvailable ? Font.DemiBold : Font.Normal
                }
            }
            Rectangle {
                visible: updater.updateAvailable && updater.changelog !== ""
                Layout.fillWidth: true
                Layout.bottomMargin: 14
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
                    wrapMode: Text.WordWrap
                }
            }
            Divider {}
            RowLayout {
                Layout.topMargin: 16
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
    }

    Component {
        id: whatsNewPage
        ColumnLayout {
            id: wn
            readonly property var info: updater.versionInfo
            spacing: 0

            // ---- the version on this device
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 8
                implicitHeight: here.implicitHeight + 36
                radius: 14
                color: Theme.accented ? Theme.alpha(Theme.primary, Theme.dark ? 0.09 : 0.07) : Theme.subtle
                border.color: Theme.accented ? Theme.alpha(Theme.primary, 0.35) : Theme.line
                ColumnLayout {
                    id: here
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        LogoMark { size: 44; colors: Theme.accentColors(Theme.accentInfo) }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: I18n.t("On this device")
                                color: Theme.dim
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            RowLayout {
                                spacing: 8
                                Label { text: "Senada " + wn.info.version; font.pixelSize: 22; font.weight: Font.Black }
                                Pill {
                                    visible: wn.info.ahead > 0
                                    text: I18n.n("+{n} change", "+{n} changes", wn.info.ahead)
                                }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: wn.info.summary
                        wrapMode: Text.WordWrap
                        font.pixelSize: 13
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 6
                        Repeater {
                            model: [
                                { k: I18n.t("Installed from"), v: wn.info.source },
                                { k: I18n.t("Commit"), v: wn.info.commit },
                                { k: I18n.t("Latest change"), v: wn.info.commitMessage },
                                { k: I18n.t("Update status"), v: updater.statusText },
                                { k: I18n.t("System"), v: wn.info.system }
                            ].filter(r => r.v)
                            delegate: Item {
                                id: cell
                                required property var modelData
                                required property int index
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                implicitHeight: Math.max(kLabel.implicitHeight, vLabel.implicitHeight)
                                Label {
                                    id: kLabel
                                    width: 130
                                    text: cell.modelData.k
                                    color: Theme.dim
                                    font.pixelSize: 12
                                }
                                Label {
                                    id: vLabel
                                    x: 148
                                    width: cell.width - x
                                    text: cell.modelData.v
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
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
                            visible: updater.updateAvailable || updater.updating
                            text: updater.updating ? I18n.t("Updating…") : I18n.t("Update & restart")
                            iconName: "download"
                            primary: true
                            enabled: !updater.updating && !updater.checking
                            onClicked: updater.applyUpdate()
                        }
                    }
                }
            }

            // ---- what changed in each version
            Label {
                Layout.topMargin: 18
                Layout.bottomMargin: 4
                text: I18n.t("Version history")
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            Repeater {
                model: updater.history
                ColumnLayout {
                    id: rel
                    required property var modelData
                    required property int index
                    readonly property bool upcoming: modelData.version === "next"
                    readonly property bool installed: upcoming || (modelData.version === wn.info.version && wn.info.ahead <= 0)
                    Layout.fillWidth: true
                    spacing: 8
                    Divider { visible: rel.index > 0; Layout.topMargin: 6; Layout.bottomMargin: 6 }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: rel.index > 0 ? 0 : 8
                        spacing: 8
                        Label {
                            text: rel.upcoming ? I18n.t("Not released yet") : "Senada " + rel.modelData.version
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                        Pill { visible: rel.installed; text: I18n.t("On this device") }
                        Pill {
                            visible: !rel.upcoming && rel.modelData.version === wn.info.version && wn.info.ahead > 0
                            text: I18n.t("Latest release")
                        }
                        Item { Layout.fillWidth: true }
                        Label { text: rel.modelData.date; color: Theme.dim; font.pixelSize: 12 }
                    }
                    Label {
                        visible: rel.upcoming
                        Layout.fillWidth: true
                        text: I18n.t("Already on this device; everyone else gets it with the next release.")
                        color: Theme.dim
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        visible: rel.modelData.new.length > 0
                        Layout.topMargin: 2
                        text: I18n.t("New").toUpperCase()
                        color: Theme.faint
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                    }
                    Repeater {
                        model: rel.modelData.new
                        Bullet { required property string modelData; text: modelData }
                    }
                    Label {
                        visible: rel.modelData.fixed.length > 0
                        Layout.topMargin: 2
                        text: I18n.t("Fixes").toUpperCase()
                        color: Theme.faint
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                    }
                    Repeater {
                        model: rel.modelData.fixed
                        Bullet { required property string modelData; text: modelData }
                    }
                }
            }
        }
    }

    Component {
        id: aboutPage
        ColumnLayout {
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 18
                spacing: 16
                LogoMark {
                    size: 52
                    colors: Theme.accentColors(Theme.accentInfo)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { text: "Senada " + updater.versionInfo.version; font.pixelSize: 22; font.weight: Font.Black }
                    Label {
                        Layout.fillWidth: true
                        text: updater.versionInfo.summary
                        color: Theme.dim
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    LinkLabel {
                        text: I18n.t("See what's new")
                        font.pixelSize: 13
                        onClicked: dlg.section = "whatsnew"
                    }
                }
            }
            Divider {}
            Note {
                text: I18n.t("Senada plays music without Spotify Premium and without ads, using a local MPV backend and a YouTube Music resolver.")
            }
            Divider {}
            SettingRow {
                label: I18n.t("License")
                hint: "GNU GPL v3"
            }
            Divider {}
            SettingRow {
                label: I18n.t("Logs")
                hint: I18n.t("If music does not play or something else goes wrong, these files show what happened. Attach them when you report a problem.")
                      + "\n" + session.logPath
                NButton {
                    text: I18n.t("Open folder")
                    iconName: "library"
                    onClicked: session.openLogFolder()
                }
            }
        }
    }
}
