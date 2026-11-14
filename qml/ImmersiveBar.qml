import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Strip along the bottom of the turntable and poster full views: title, artist and like
// on the left, transport and seek bar in the middle, volume on the right.
Item {
    id: bar
    signal closeRequested()   // a link leads out of the full view
    readonly property var s: player ? player.state : ({})

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.4) }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 10
        anchors.bottomMargin: 18
        spacing: 28

        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.27
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: bar.s.name || I18n.t("Nothing is playing")
                font.pixelSize: 20
                font.weight: Font.Black
                color: "#ffffff"
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                LinkLabel {
                    Layout.maximumWidth: parent.width - 36
                    text: bar.s.artists || ""
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.72)
                    elide: Text.ElideRight
                    onClicked: if (bar.s.artistId) { bar.closeRequested(); Nav.go("artist", bar.s.artistId) }
                }
                IconButton {
                    visible: !!bar.s.hasTrack
                    implicitWidth: 28
                    iconName: bar.s.liked ? "heart" : "heart-outline"
                    size: 16
                    tint: bar.s.liked ? Theme.like : Qt.rgba(1, 1, 1, 0.7)
                    tip: bar.s.liked ? I18n.t("Remove from Liked Songs") : I18n.t("Save to Liked Songs")
                    onClicked: player.toggleLike()
                }
                Item { Layout.fillWidth: true }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            ImmersiveTransport {
                Layout.alignment: Qt.AlignHCenter
                playSize: 50
                spacing: 20
            }
            ImmersiveSeek {
                Layout.fillWidth: true
                Layout.maximumWidth: 560
                Layout.alignment: Qt.AlignHCenter
            }
        }

        ImmersiveVolume {
            Layout.preferredWidth: Math.min(200, parent.width * 0.18)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
