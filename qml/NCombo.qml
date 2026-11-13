import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dropdown in the app's style.
//   model: [{ key, label }], `value` = the selected key; picking an entry emits picked(key)
ComboBox {
    id: cb
    property var value
    signal picked(var key)

    textRole: "label"
    // looked up in the model by hand: indexOfValue() is not re-run when the model arrives
    currentIndex: {
        const m = model || []
        for (let i = 0; i < m.length; ++i)
            if (m[i].key === value) return i
        return 0
    }
    onActivated: (i) => picked(model[i].key)

    implicitWidth: 200
    implicitHeight: 36
    leftPadding: 14
    rightPadding: 36
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    font.pixelSize: 13

    background: Rectangle {
        radius: 10
        color: cb.pressed || cb.popup.visible ? Theme.pressed : cb.hovered ? Theme.hover : Theme.subtle
        border.width: 1
        border.color: cb.popup.visible && Theme.accented ? Theme.primary : cb.popup.visible || cb.hovered ? Theme.lineStrong : Theme.line
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Label {
        text: cb.displayText
        font.pixelSize: 13
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: cb.width - width - 12
        y: (cb.height - height) / 2
        glyph: "expand-more"
        size: 18
        color: Theme.dim
        rotation: cb.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    delegate: ItemDelegate {
        id: item
        required property int index
        width: ListView.view ? ListView.view.width : cb.width
        implicitHeight: 34
        leftPadding: 10
        rightPadding: 10
        highlighted: cb.highlightedIndex === index
        hoverEnabled: true
        contentItem: RowLayout {
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: cb.textAt(item.index)
                font.pixelSize: 13
                font.weight: cb.currentIndex === item.index ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Icon {
                visible: cb.currentIndex === item.index
                glyph: "check"
                size: 16
                color: Theme.accentInk
            }
        }
        background: Rectangle {
            radius: 7
            color: item.highlighted || item.hovered ? Theme.hover : "transparent"
        }
    }

    popup: Popup {
        y: cb.height + 4
        width: cb.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: cb.popup.visible ? cb.delegateModel : null
            currentIndex: cb.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }
        background: Rectangle {
            radius: 10
            color: Theme.surface2
            border.color: Theme.line
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }
    }
}
