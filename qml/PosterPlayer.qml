import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full view as a magazine poster (Settings → Appearance → Full view style): the cover sharp
// and large on a field of its own colour, the title set huge and vertical beside it, and an
// editorial column on the right: the artist as a headline, then the lyrics as a pull quote
// (the sung line big, the next one under it), the queue as a numbered track list, or the
// equalizer as a column of fine sliders. Controls sit in a strip along the bottom.
Item {
    id: pp
    property bool active: true            // the full view is on screen
    property string panel: "lyrics"       // "lyrics" | "queue" | "equalizer"
    property bool showPanel: true
    signal closeRequested()
    readonly property var s: player ? player.state : ({})

    readonly property real topSpace: 68
    readonly property real bottomSpace: 116
    readonly property real areaH: height - topSpace - bottomSpace
    readonly property color ink: "#ffffff"
    readonly property color accent: Qt.lighter(Theme.accent, 1.15)
    readonly property string serif: "Georgia"

    // a field of the cover's own colour over the blurred art
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.accent.r * 0.35, Theme.accent.g * 0.35, Theme.accent.b * 0.35, 0.85) }
            GradientStop { position: 0.6; color: Qt.rgba(0.04, 0.04, 0.05, 0.8) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.02, 0.03, 0.88) }
        }
    }

    // ---- the cover and the vertical title -------------------------------------------------------
    readonly property real coverSide: Math.max(220, Math.min(areaH - 16, width * (showPanel ? 0.38 : 0.46)))
    Item {
        id: art
        x: 56
        y: pp.topSpace + (pp.areaH - height) / 2
        width: pp.coverSide
        height: width
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Rectangle {
            id: artShape
            anchors.fill: parent
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: artShape
            source: artShape
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.7
            shadowBlur: 1.0
            shadowVerticalOffset: 20
            shadowHorizontalOffset: 10
        }
        Cover {
            anchors.fill: parent
            radius: 2
            source: Theme.hiRes(pp.s.imageLarge || pp.s.image, 1200)
            fallback: pp.s.imageLarge || pp.s.image || ""
        }
        // issue line across the top of the cover, like a magazine
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30
            color: Qt.rgba(0, 0, 0, 0.45)
            Label {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "SENADA  ·  " + I18n.t("NOW PLAYING")
                color: "#ffffff"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 2.4
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: pp.s.hasTrack ? Theme.fmt(pp.s.durationMs || 0) : ""
                color: "#ffffff"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
        HoverHandler { cursorShape: pp.s.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (pp.s.hasTrack) player.togglePlay() }
    }
    // the title, huge, running up beside the cover
    Item {
        id: spine
        x: art.x + art.width + 18
        y: art.y
        width: titleLabel.height
        height: art.height
        Label {
            id: titleLabel
            anchors.centerIn: parent
            width: parent.height
            rotation: -90
            text: (pp.s.name || I18n.t("Nothing is playing")).toUpperCase()
            color: pp.ink
            font.pixelSize: Math.round(Math.max(30, Math.min(110, pp.coverSide * 0.15)))
            font.weight: Font.Black
            font.letterSpacing: -1
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }
    }

    // ---- the editorial column -----------------------------------------------------------------
    Item {
        id: column
        x: spine.x + spine.width + 48
        y: pp.topSpace + 8
        width: pp.width - x - 96   // the volume rail is on the right edge
        height: pp.areaH - 16

        ColumnLayout {
            id: head
            width: parent.width
            spacing: 6
            Rectangle { width: 46; height: 4; color: pp.accent }
            LinkLabel {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: pp.s.artists || ""
                color: pp.ink
                font.family: pp.serif
                font.pixelSize: Math.round(Math.max(28, Math.min(52, column.width * 0.075)))
                font.weight: Font.Bold
                elide: Text.ElideRight
                onClicked: if (pp.s.artistId || pp.s.artists) { pp.closeRequested(); Nav.goArtist(pp.s) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                LinkLabel {
                    Layout.maximumWidth: column.width - 120
                    visible: !!pp.s.album
                    text: pp.s.album || ""
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.family: pp.serif
                    font.pixelSize: 16
                    font.italic: true
                    elide: Text.ElideRight
                    onClicked: if (pp.s.albumId) { pp.closeRequested(); Nav.go("album", pp.s.albumId) }
                }
                IconButton {
                    visible: !!pp.s.hasTrack
                    implicitWidth: 30
                    iconName: pp.s.liked ? "heart" : "heart-outline"
                    size: 16
                    tint: pp.s.liked ? Theme.like : Qt.rgba(1, 1, 1, 0.75)
                    tip: pp.s.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                    onClicked: player.toggleLike()
                }
                DownloadButton {
                    visible: !!pp.s.hasTrack
                    track: pp.s
                    size: 15
                    tint: Qt.rgba(1, 1, 1, 0.75)
                }
                Item { Layout.fillWidth: true }
            }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
        }

        // what fills the rest of the column
        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: head.bottom
            anchors.topMargin: 22
            anchors.bottom: parent.bottom
            visible: pp.showPanel

            // lyrics as a pull quote ---------------------------------------------------------
            Item {
                id: quoteBox
                anchors.fill: parent
                visible: pp.panel === "lyrics"
                readonly property var lines: lyrics.status === "ready" ? lyrics.lines : []
                readonly property int at: lyrics.synced ? Math.max(-1, lyrics.current) : -1
                readonly property bool quote: lyrics.synced && lines.length > 0

                // the sung line as a big pull quote about a third of the way down the column, the
                // lines already sung fading out above it and the lines to come filling the column
                // below it like the body of an article; click a line to go to it
                readonly property int before: 3
                clip: true

                Column {
                    id: sungBefore
                    width: parent.width
                    anchors.bottom: quoteRow.top
                    anchors.bottomMargin: 16
                    spacing: 10
                    visible: quoteBox.quote
                    Repeater {
                        id: sungLines
                        model: quoteBox.quote ? quoteBox.lines.slice(Math.max(0, quoteBox.at - quoteBox.before), Math.max(0, quoteBox.at)) : []
                        Label {
                            required property var modelData
                            required property int index
                            readonly property int away: sungLines.count - index   // 1 = the line just sung
                            width: sungBefore.width
                            leftPadding: 60
                            text: modelData.text || "♪"
                            color: pastHover.hovered ? pp.ink : Qt.rgba(1, 1, 1, Math.max(0.1, 0.4 - 0.1 * away))
                            font.family: pp.serif
                            font.pixelSize: 17
                            font.italic: true
                            elide: Text.ElideRight
                            HoverHandler { id: pastHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: player.seek(modelData.t) }
                        }
                    }
                }
                Row {
                    id: quoteRow
                    width: parent.width
                    // a third of the way down, but always below the lines already sung
                    y: Math.max(sungBefore.implicitHeight + 16, Math.round(quoteBox.height * 0.3 - height / 2))
                    spacing: 10
                    visible: quoteBox.quote
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Label {
                        text: "“"
                        color: pp.accent
                        font.family: pp.serif
                        font.pixelSize: 96
                        font.weight: Font.Bold
                        height: 70
                    }
                    Label {
                        id: sung
                        width: parent.width - 60
                        text: quoteBox.at >= 0 ? (quoteBox.lines[quoteBox.at].text || "♪") : "♪"
                        color: pp.ink
                        font.family: pp.serif
                        font.pixelSize: Math.round(Math.max(26, Math.min(48, body.width * 0.06)))
                        font.italic: true
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        topPadding: 14
                        opacity: 1
                        // fade in each new line
                        onTextChanged: { opacity = 0.2; fadeIn.restart() }
                        NumberAnimation { id: fadeIn; target: sung; property: "opacity"; to: 1; duration: 380 }
                    }
                }
                Column {
                    id: comingUp
                    width: parent.width
                    anchors.top: quoteRow.bottom
                    anchors.topMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40   // the lyrics source button
                    spacing: 12
                    clip: true
                    visible: quoteBox.quote
                    // the last lines fade out instead of being cut in half
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: comingFade
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    Repeater {
                        // as many as can fit; those that do not are cut off by the clip
                        model: quoteBox.quote ? quoteBox.lines.slice(quoteBox.at + 1, quoteBox.at + 1 + 24) : []
                        Label {
                            required property var modelData
                            required property int index
                            width: comingUp.width
                            leftPadding: 60
                            text: modelData.text || "♪"
                            color: lineHover.hovered ? pp.ink : Qt.rgba(1, 1, 1, Math.max(0.12, 0.62 - 0.07 * index))
                            font.family: pp.serif
                            font.pixelSize: index === 0 ? 21 : 18
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            HoverHandler { id: lineHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: player.seek(modelData.t) }
                        }
                    }
                }
                Rectangle {
                    id: comingFade
                    anchors.fill: comingUp
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "black" }
                        GradientStop { position: Math.max(0.5, 1 - 90 / Math.max(1, comingFade.height)); color: "black" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                // plain (unsynced) lyrics: the whole text as a column of verse
                Flickable {
                    id: verse
                    anchors.fill: parent
                    visible: !quoteBox.quote && lyrics.status === "ready"
                    contentHeight: verseText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: NScrollBar {}
                    Label {
                        id: verseText
                        width: verse.width - 16
                        text: (lyrics.lines || []).map(l => l.text).join("\n")
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.family: pp.serif
                        font.pixelSize: 18
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                    }
                }
                Label {
                    visible: lyrics.status !== "ready"
                    width: parent.width
                    text: ({ "loading": I18n.t("Loading lyrics…"), "none": I18n.t("No lyrics found for this song"),
                             "error": I18n.t("Could not load lyrics"), "idle": I18n.t("Play a song to see its lyrics") })[lyrics.status] || ""
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: pp.serif
                    font.pixelSize: 20
                    font.italic: true
                    wrapMode: Text.WordWrap
                }
                LyricsSourceButton {
                    anchors.bottom: parent.bottom
                    visible: lyrics.status !== "idle"
                    tint: Qt.rgba(1, 1, 1, 0.5)
                    hoverTint: "#ffffff"
                }
            }

            // queue as a numbered track list -------------------------------------------------
            ListView {
                id: tracks
                anchors.fill: parent
                visible: pp.panel === "queue"
                clip: true
                model: visible ? player.queue : []
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: NScrollBar {}
                SmoothScroll { flickable: tracks }
                Component.onCompleted: player.refreshQueue()
                header: Label {
                    text: I18n.t("UP NEXT")
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2.4
                    bottomPadding: 10
                }
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    width: tracks.width - 12
                    height: 62
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        text: (entry.index + 1 < 10 ? "0" : "") + (entry.index + 1)
                        color: pp.accent
                        font.pixelSize: 30
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                    }
                    Column {
                        x: 70
                        width: parent.width - 70 - 56
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            text: entry.modelData.name || ""
                            color: entryHover.hovered ? pp.accent : pp.ink
                            font.family: pp.serif
                            font.pixelSize: 19
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: entry.modelData.artists || ""
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.durationMs ? Theme.fmt(entry.modelData.durationMs) : ""
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                    HoverHandler { id: entryHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: player.skip(entry.index + 1) }
                }
                Label {
                    anchors.centerIn: parent
                    visible: tracks.count === 0
                    text: I18n.t("The queue is empty")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: pp.serif
                    font.pixelSize: 18
                    font.italic: true
                }
            }

            // equalizer as a column of fine sliders ------------------------------------------
            EqualizerLines {
                anchors.fill: parent
                visible: pp.panel === "equalizer"
                ink: pp.ink
                accent: pp.accent
                family: pp.serif
            }
        }
    }

    // ---- controls along the bottom ---------------------------------------------------------
    ImmersiveBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: pp.bottomSpace
        onCloseRequested: pp.closeRequested()
    }
}
