import QtQuick
import "../core"

// The bell island: unread count badge. The surrounding bar popover trigger
// owns activation; this only renders the state.
FocusScope {
    id: root

    property bool open: false

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.name: Notifications.unread > 0
        ? "Notifications, " + Notifications.unread + " unread" : "Notifications"
    Accessible.role: Accessible.Button

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: Notifications.doNotDisturb
                ? "../assets/icons/bell-off.svg"
                : "../assets/icons/bell.svg"
            sourceSize.width: 16
            sourceSize.height: 16
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.unread > 0
            text: Notifications.unread > 9 ? "9+" : String(Notifications.unread)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.open || root.activeFocus || hover.hovered
            ? Theme.hoverFill
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.open ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.orange
        z: -1
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
