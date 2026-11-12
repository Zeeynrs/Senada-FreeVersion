import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top toolbar: sidebar toggle, back / forward, and on the right search and the
// right-panel (lyrics / queue) toggle.
Rectangle {
    id: top
    property bool canGoBack: false
    property bool canGoForward: false
    property bool sidebarOpen: true
    property string panel: ""
    signal toggleSidebar()
    signal back()
    signal forward()
    signal togglePanel()

    implicitHeight: 48
    color: Theme.sidebar

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 2

        IconButton {
            iconName: "sidebar"
            size: 18
            tint: Theme.dim
            active: top.sidebarOpen
            tip: top.sidebarOpen ? "Sembunyikan sidebar (Ctrl+B)" : "Tampilkan sidebar (Ctrl+B)"
            onClicked: top.toggleSidebar()
        }
        Item { Layout.preferredWidth: Math.max(0, (top.sidebarOpen ? Theme.sidebarWidth : 0) - 50) }
        IconButton {
            iconName: "back"
            size: 18
            enabled: top.canGoBack
            tip: "Kembali (Alt+←)"
            onClicked: top.back()
        }
        IconButton {
            iconName: "forward"
            size: 18
            enabled: top.canGoForward
            tip: "Maju (Alt+→)"
            onClicked: top.forward()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            iconName: "search"
            size: 18
            tint: Theme.dim
            tip: "Cari (Ctrl+F)"
            onClicked: Nav.go("search")
        }
        IconButton {
            iconName: "panel"
            size: 18
            tint: Theme.dim
            active: top.panel !== ""
            tip: top.panel !== "" ? "Tutup panel kanan" : "Buka panel lirik & antrean"
            onClicked: top.togglePanel()
        }
    }
}
