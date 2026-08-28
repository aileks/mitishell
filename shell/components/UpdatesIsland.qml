import QtQuick
import "../core"

Item {
    property bool open: false
    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.name: Updates.state === "error" ? "Update check failed" : Updates.count + " available updates"

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spaceXs
        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Icons.packageIcon
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
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
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    }
}
