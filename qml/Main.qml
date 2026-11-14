import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: player.state.hasTrack ? player.state.name + " • " + player.state.artists : "Senada"
    // see-through only in the "Transparan" glass mode (the compositor / Windows acrylic shows behind)
    color: Theme.glassMode === "desktop" ? "transparent" : Theme.bgSolid

    // light / dark follows the system unless chosen in Settings
    Binding { target: Theme; property: "mode"; value: session.themeMode }
    Binding { target: Theme; property: "accentName"; value: session.accentColor }
    Binding { target: Theme; property: "accentStrength"; value: session.accentStrength }
    Binding { target: Theme; property: "glassMode"; value: session.glassMode }
    Binding { target: Theme; property: "glassOpacity"; value: session.glassOpacity }
    Binding { target: Theme; property: "lyricsSize"; value: session.lyricsSize }
    Binding { target: Theme; property: "lyricsFont"; value: session.lyricsFont }
    Binding { target: Theme; property: "lyricsAlign"; value: session.lyricsAlign }
    Binding { target: Theme; property: "lyricsHighlight"; value: session.lyricsHighlight }
    Binding { target: I18n; property: "table"; value: session.translations }
    Binding { target: I18n; property: "lang"; value: session.language }

    palette {
        window: Theme.bgSolid
        windowText: Theme.text
        text: Theme.text
        base: Theme.surface2
        alternateBase: Theme.surface3
        button: Theme.surface2
        buttonText: Theme.text
        highlight: Theme.primary
        highlightedText: Theme.primaryText
        placeholderText: Theme.faint
        toolTipBase: Theme.surface2
        toolTipText: Theme.text
        light: Theme.surface3
        midlight: Theme.surface3
        mid: Theme.surface2
        dark: Theme.surface
        shadow: "#000000"
    }

    // album-art colour for the immersive player, eased so it doesn't flash between tracks
    property color liveAccent: player.accent
    Behavior on liveAccent { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    Binding { target: Theme; property: "accent"; value: win.liveAccent }

    // full-rate position updates only while someone can look at them: the focused window or
    // the mini player (it shows the ring, the time and the lyrics)
    readonly property bool watched: active || miniMode
    onWatchedChanged: player.setFastPolling(watched)
    Component.onCompleted: player.setFastPolling(watched)

    // ---- mini player ("dynamic island") while minimized ----------------------------------
    property bool miniMode: false
    property bool wasMaximized: false
    readonly property bool hidesToMini: Qt.platform.pluginName.indexOf("wayland") === 0

    // Wayland compositors seldom minimize (Hyprland never does) and never say so, so there
    // the button and Ctrl+M hide the window instead
    function enterMiniPlayer() {
        if (!player.state.hasTrack)
            return
        miniMode = true
        if (hidesToMini) win.hide()
        else win.showMinimized()
    }
    function leaveMiniPlayer() {
        miniMode = false
        if (win.wasMaximized) win.showMaximized()
        else win.showNormal()
        win.raise()
        win.requestActivate()
    }
    onVisibilityChanged: {
        if (visibility === Window.Minimized) {
            if (session.miniPlayer && player.state.hasTrack)
                miniMode = true
        } else if (visibility !== Window.Hidden) {
            miniMode = false
            wasMaximized = visibility === Window.Maximized
        }
    }
    onClosing: miniMode = false
    onMiniModeChanged: {
        if (miniMode) {
            mini.place(win.screen)
            mini.show()
        } else {
            mini.hide()
        }
    }
    MiniPlayer {
        id: mini
        onRestore: win.leaveMiniPlayer()
        // closed from the compositor: the main window comes back (refusing the close
        // would also refuse Qt.quit())
        onVisibleChanged: if (!visible && win.miniMode) win.leaveMiniPlayer()
    }

    // no account needed: the app opens straight into the library
    AppShell { anchors.fill: parent }

    Connections {
        target: session
        function onToast(msg) { toast.show(msg) }
    }
    Toast { id: toast }
}
