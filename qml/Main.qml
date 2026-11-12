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
    Binding { target: Theme; property: "glassMode"; value: session.glassMode }
    Binding { target: Theme; property: "glassOpacity"; value: session.glassOpacity }

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

    onActiveChanged: player.setFastPolling(active)

    // no account needed: the app opens straight into the library
    AppShell { anchors.fill: parent }

    Connections {
        target: session
        function onToast(msg) { toast.show(msg) }
    }
    Toast { id: toast }
}
