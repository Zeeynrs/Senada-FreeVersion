import QtQuick
import Qt.labs.platform as Platform

// Senada's icon in the system tray (next to the clock): play / pause, skip, open and quit.
// Main.qml loads it through a Loader: on a Qt without the Qt.labs.platform module (some Linux
// distributions package it separately) only the tray is missing, not the whole interface.
Item {
    id: root
    readonly property bool shown: icon.visible  // false on a desktop without a tray
    signal showWindow()

    function showMessage(title, text) {
        icon.showMessage(title, text)
    }

    Platform.SystemTrayIcon {
        id: icon
        visible: session.trayIcon && available
        icon.source: Qt.resolvedUrl("../data/senada.png")
        tooltip: player.state.hasTrack ? player.state.name + " • " + player.state.artists : "Senada"
        // a click brings the window back (the tray takes the focus first, so it can't tell
        // whether the window was in front to toggle it away)
        onActivated: (reason) => {
            if (reason !== Platform.SystemTrayIcon.Context)
                root.showWindow()
        }
        menu: Platform.Menu {
            Platform.MenuItem {
                visible: player.state.hasTrack
                enabled: false
                text: player.state.hasTrack ? player.state.name + " • " + player.state.artists : ""
            }
            Platform.MenuSeparator { visible: player.state.hasTrack }
            Platform.MenuItem {
                enabled: player.state.hasTrack
                text: player.state.isPlaying ? I18n.t("Pause") : I18n.t("Play")
                onTriggered: player.togglePlay()
            }
            Platform.MenuItem {
                enabled: player.state.hasTrack
                text: I18n.t("Next song")
                onTriggered: player.next()
            }
            Platform.MenuItem {
                enabled: player.state.hasTrack
                text: I18n.t("Previous song")
                onTriggered: player.previous()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: I18n.t("Open Senada")
                onTriggered: root.showWindow()
            }
            Platform.MenuItem {
                text: I18n.t("Quit Senada")
                onTriggered: session.quit()
            }
        }
    }
}
