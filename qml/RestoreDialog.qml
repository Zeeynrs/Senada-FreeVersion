import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Restore a backup" (Settings → Profile & Library): what the backup holds, whether to add it to
// the library or replace the library with it, and whether the settings come back too.
// The work is done by senada/backup.py.
Popup {
    id: rd
    property url file
    property var info: ({})
    property string mode: "merge"   // "merge" | "replace"
    property bool withSettings: false

    function openFor(url) {
        file = url
        info = backup.inspect(url)
        mode = "merge"
        withSettings = false
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(540, parent ? parent.width - 48 : 540)
    modal: true
    focus: true
    padding: 24
    background: Rectangle { radius: 16; color: Theme.surface2; border.color: Theme.line }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    // one of the two ways to restore
    component ModeOption: AbstractButton {
        id: mo
        property string key
        property string title
        property string body
        readonly property bool chosen: rd.mode === key
        Layout.fillWidth: true
        implicitHeight: modeText.implicitHeight + 24
        hoverEnabled: true
        onClicked: rd.mode = key
        background: Rectangle {
            radius: 12
            color: mo.chosen ? Theme.alpha(Theme.primary, 0.12) : mo.hovered ? Theme.hover : "transparent"
            border.color: mo.chosen ? Theme.alpha(Theme.primary, 0.6) : Theme.line
        }
        contentItem: RowLayout {
            spacing: 12
            Rectangle {  // the radio dot
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                implicitWidth: 16; implicitHeight: 16; radius: 8
                color: "transparent"
                border.width: mo.chosen ? 5 : 1.5
                border.color: mo.chosen ? Theme.primary : Theme.dim
            }
            ColumnLayout {
                id: modeText
                Layout.fillWidth: true
                spacing: 2
                Label { text: mo.title; font.pixelSize: 14; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    text: mo.body
                    color: Theme.dim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
        leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
    }

    contentItem: ColumnLayout {
        spacing: 14

        Label { text: I18n.t("Restore a backup"); font.pixelSize: 20; font.weight: Font.Bold }

        // not a backup, or unreadable
        Label {
            Layout.fillWidth: true
            visible: !rd.info.ok
            text: rd.info.error || ""
            color: Theme.danger
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            visible: !!rd.info.ok
            text: [I18n.n("{n} liked song", "{n} liked songs", rd.info.liked || 0),
                   I18n.n("{n} playlist", "{n} playlists", rd.info.playlists || 0),
                   I18n.n("{n} saved album or artist", "{n} saved albums and artists", rd.info.saved || 0),
                   I18n.n("{n} song in history", "{n} songs in history", rd.info.history || 0)].join("  ·  ")
                  + (rd.info.created ? "\n" + I18n.t("Made on {date}", { date: rd.info.created }) : "")
            color: Theme.dim
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        ModeOption {
            visible: !!rd.info.ok
            key: "merge"
            title: I18n.t("Add to my library")
            body: I18n.t("What the backup has and your library lacks is added. Nothing you have now is removed.")
        }
        ModeOption {
            visible: !!rd.info.ok
            key: "replace"
            title: I18n.t("Replace my library")
            body: I18n.t("Your library becomes exactly the backup: what is not in it is removed.")
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !!rd.info.ok && !!rd.info.hasSettings
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: I18n.t("Restore the settings too"); font.pixelSize: 14; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    text: I18n.t("Theme, lyrics, sound and the rest. Senada restarts to apply them.")
                    color: Theme.dim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
            NSwitch {
                checked: rd.withSettings
                onToggled: rd.withSettings = checked
            }
        }

        Label {
            Layout.fillWidth: true
            visible: !!rd.info.ok
            text: I18n.t("Your library as it is now is copied to the automatic backups first, so this can be undone.")
            color: Theme.faint
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10
            Item { Layout.fillWidth: true }
            NButton {
                text: rd.info.ok ? I18n.t("Cancel") : I18n.t("Close")
                onClicked: rd.close()
            }
            NButton {
                visible: !!rd.info.ok
                primary: true
                text: I18n.t("Restore")
                onClicked: {
                    if (backup.restore(rd.file, rd.mode, rd.withSettings))
                        rd.close()
                }
            }
        }
    }
}
