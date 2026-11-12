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
    Rectangle { width: parent.width; height: 1; color: Theme.sheen }  // liquid-glass sheen

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
            tip: top.sidebarOpen ? I18n.t("Hide sidebar (Ctrl+B)") : I18n.t("Show sidebar (Ctrl+B)")
            onClicked: top.toggleSidebar()
        }
        Item { Layout.preferredWidth: Math.max(0, (top.sidebarOpen ? Theme.sidebarWidth : 0) - 50) }
        IconButton {
            iconName: "back"
            size: 18
            enabled: top.canGoBack
            tip: I18n.t("Back (Alt+←)")
            onClicked: top.back()
        }
        IconButton {
            iconName: "forward"
            size: 18
            enabled: top.canGoForward
            tip: I18n.t("Forward (Alt+→)")
            onClicked: top.forward()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            iconName: "search"
            size: 18
            tint: Theme.dim
            tip: I18n.t("Search (Ctrl+F)")
            onClicked: Nav.go("search")
        }
        IconButton {
            iconName: "panel"
            size: 18
            tint: Theme.dim
            active: top.panel !== ""
            tip: top.panel !== "" ? I18n.t("Close right panel") : I18n.t("Open lyrics & queue panel")
            onClicked: top.togglePanel()
        }
    }
}
