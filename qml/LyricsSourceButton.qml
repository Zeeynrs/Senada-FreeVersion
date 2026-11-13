import QtQuick
import QtQuick.Controls

// "Lyrics: LRCLIB ▾" under the lyrics; opens a menu to pick another lyrics source.
Item {
    id: btn
    property color tint: Theme.dim       // label colour (light in the immersive view)
    property color hoverTint: Theme.text
    property int fontSize: 12

    function label(key, name) {
        return key === "auto" ? I18n.t("Automatic") : name
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + 8

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Label {
            anchors.verticalCenter: parent.verticalCenter
            color: hover.hovered ? btn.hoverTint : btn.tint
            font.pixelSize: btn.fontSize
            text: {
                const name = lyrics.source === "auto"
                    ? I18n.t("Automatic") + (lyrics.sourceName ? " · " + lyrics.sourceName : "")
                    : lyrics.sources.find(s => s.key === lyrics.source).name
                return I18n.t("Lyrics source: {name}", { name: name })
            }
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: "chevron-down"
            size: btn.fontSize + 2
            color: hover.hovered ? btn.hoverTint : btn.tint
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: menu.popup(btn, 0, btn.height) }

    NMenu {
        id: menu
        Instantiator {
            model: lyrics.sources
            delegate: MenuItem {
                required property var modelData
                text: (lyrics.source === modelData.key ? "✓  " : "     ") + btn.label(modelData.key, modelData.name)
                onTriggered: lyrics.source = modelData.key
            }
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
