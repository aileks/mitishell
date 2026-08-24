import QtQuick
import "../core"

Item {
    property bool open: false
    implicitWidth: content.implicitWidth + Theme.spaceSm * 2
    implicitHeight: 24
    Accessible.name: Updates.state === "error" ? "Update check failed" : Updates.count + " available updates"

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spaceXs
        Text { text: "󰏔"; color: Updates.state === "error" ? Theme.red : Theme.text; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBody }
        Text {
            visible: Updates.count > 0
            text: String(Updates.count)
            color: Theme.yellow
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
    Rectangle {
        anchors.fill: parent
        z: -1
        radius: Theme.radiusPill
        color: parent.open || hover.hovered ? Theme.hoverFill : "transparent"
        border.width: parent.open ? 1 : 0
        border.color: Theme.yellow
        HoverHandler { id: hover }
    }
}
