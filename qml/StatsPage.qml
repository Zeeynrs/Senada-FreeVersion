import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Your stats": how much was listened to in a period, the minutes per day or month as bars,
// and the top songs and artists (senada/stats.py). Recorded on this device only.
Item {
    id: page
    readonly property string pageKey: "stats"
    property string period: "month"   // week | month | year | all
    property var info: stats.summary(period)
    readonly property int maxBar: Math.max(1, ...(info.bars || []).map(b => b.minutes))

    function refresh() { info = stats.summary(period) }
    onPeriodChanged: refresh()
    Connections {
        target: stats
        function onChanged() { page.refresh() }
    }

    function minutesText(m) {
        return m >= 120 ? I18n.t("{n} h", { n: Math.round(m / 60) }) : I18n.t("{n} min", { n: m })
    }

    // one big number with its label
    component Tile: Rectangle {
        id: tile
        property string value
        property string label
        Layout.fillWidth: true
        implicitHeight: 96
        radius: 16
        color: Theme.surface
        border.color: Theme.line
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { text: tile.value; font.pixelSize: 30; font.weight: Font.Black; font.features: { "tnum": 1 } }
            Label { text: tile.label; color: Theme.dim; font.pixelSize: 13 }
        }
    }

    Flickable {
        id: flick
        SmoothScroll { flickable: flick }
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.dockSpace + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 28
            y: 24
            width: flick.width - 56
            spacing: 28

            // ---- title and period -------------------------------------------------------
            Column {
                width: parent.width
                spacing: 12
                Label { text: I18n.t("Your stats"); font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: -0.6 }
                Label {
                    width: parent.width
                    text: page.info.since
                          ? I18n.t("Counted on this device since {date}. A song counts after 30 seconds.", { date: page.info.since })
                          : I18n.t("Play some songs: every song heard for 30 seconds is counted here, on this device only.")
                    color: Theme.dim
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: [{ key: "week", label: I18n.t("Last 7 days") }, { key: "month", label: I18n.t("Last 30 days") },
                                { key: "year", label: I18n.t("This year") }, { key: "all", label: I18n.t("All time") }]
                        delegate: Chip {
                            required property var modelData
                            text: modelData.label
                            checked: page.period === modelData.key
                            onClicked: page.period = modelData.key
                        }
                    }
                }
            }

            // ---- the totals ---------------------------------------------------------------
            RowLayout {
                width: parent.width
                spacing: 14
                Tile { value: page.minutesText(page.info.minutes || 0); label: I18n.t("listened") }
                Tile { value: String(page.info.plays || 0); label: I18n.t("plays") }
                Tile { value: String(page.info.songs || 0); label: I18n.t("different songs") }
                Tile { value: String(page.info.artists || 0); label: I18n.t("artists") }
            }

            // ---- minutes per day / month ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 10
                Label {
                    text: page.period === "week" || page.period === "month" ? I18n.t("Minutes per day") : I18n.t("Minutes per month")
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                Item {
                    width: parent.width
                    height: 150
                    Row {
                        id: barRow
                        anchors.fill: parent
                        anchors.bottomMargin: 20
                        spacing: 4
                        readonly property int count: Math.max(1, (page.info.bars || []).length)
                        Repeater {
                            model: page.info.bars || []
                            delegate: Item {
                                id: bar
                                required property var modelData
                                required property int index
                                width: (barRow.width - barRow.spacing * (barRow.count - 1)) / barRow.count
                                height: barRow.height
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    radius: Math.min(4, width / 2)
                                    height: modelData.minutes > 0 ? Math.max(3, parent.height * modelData.minutes / page.maxBar) : 2
                                    color: modelData.minutes > 0 ? (barHover.hovered ? Theme.primary : Theme.alpha(Theme.primary, 0.7))
                                                                 : Theme.line
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                                Label {
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: barRow.count <= 14 || (barRow.count - 1 - bar.index) % 5 === 0
                                    text: bar.modelData.label
                                    color: Theme.faint
                                    font.pixelSize: 10
                                }
                                HoverHandler { id: barHover }
                                ToolTip.visible: barHover.hovered
                                ToolTip.text: modelData.key + "  ·  " + page.minutesText(modelData.minutes)
                                ToolTip.delay: 200
                            }
                        }
                    }
                }
            }

            // ---- top songs and top artists --------------------------------------------------
            RowLayout {
                width: parent.width
                spacing: 28

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    Label { text: I18n.t("Top songs"); font.pixelSize: 18; font.weight: Font.Bold; Layout.bottomMargin: 6 }
                    Label {
                        visible: (page.info.topSongs || []).length === 0
                        text: I18n.t("Nothing yet in this period.")
                        color: Theme.dim
                    }
                    Repeater {
                        model: page.info.topSongs || []
                        delegate: ItemDelegate {
                            id: songRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 58
                            padding: 8
                            background: Rectangle { radius: 10; color: songRow.hovered ? Theme.hover : "transparent" }
                            onClicked: stats.play(page.info.topSongs, index)
                            contentItem: RowLayout {
                                spacing: 12
                                Label {
                                    Layout.preferredWidth: 22
                                    text: String(songRow.index + 1)
                                    color: Theme.faint
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignRight
                                }
                                Cover {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 6
                                    source: songRow.modelData.imageSmall || ""
                                    fallbackIcon: "music"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label { Layout.fillWidth: true; text: songRow.modelData.name || ""; font.pixelSize: 14; elide: Text.ElideRight }
                                    Label { Layout.fillWidth: true; text: songRow.modelData.artists || ""; color: Theme.dim; font.pixelSize: 12; elide: Text.ElideRight }
                                }
                                Label {
                                    text: I18n.n("{n} play", "{n} plays", songRow.modelData.plays)
                                    color: Theme.dim
                                    font.pixelSize: 12
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    Label { text: I18n.t("Top artists"); font.pixelSize: 18; font.weight: Font.Bold; Layout.bottomMargin: 6 }
                    Label {
                        visible: (page.info.topArtists || []).length === 0
                        text: I18n.t("Nothing yet in this period.")
                        color: Theme.dim
                    }
                    Repeater {
                        model: page.info.topArtists || []
                        delegate: ItemDelegate {
                            id: artistRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 58
                            padding: 8
                            background: Rectangle { radius: 10; color: artistRow.hovered ? Theme.hover : "transparent" }
                            onClicked: Nav.findArtist(artistRow.modelData.name)
                            contentItem: RowLayout {
                                spacing: 12
                                Label {
                                    Layout.preferredWidth: 22
                                    text: String(artistRow.index + 1)
                                    color: Theme.faint
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignRight
                                }
                                Cover {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    round: true
                                    source: artistRow.modelData.imageSmall || ""
                                    fallbackIcon: "person"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label { Layout.fillWidth: true; text: artistRow.modelData.name; font.pixelSize: 14; elide: Text.ElideRight }
                                    Label {
                                        Layout.fillWidth: true
                                        text: I18n.n("{n} play", "{n} plays", artistRow.modelData.plays) + "  ·  " + page.minutesText(artistRow.modelData.minutes)
                                        color: Theme.dim
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
