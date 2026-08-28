import QtQuick
import "../core"

// The bell widget: unread count badge. The surrounding bar popover trigger
// owns activation; this only renders the state.
FocusScope {
    id: root

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.name: Notifications.unread > 0
        ? "Notifications, " + Notifications.unread + " unread" : "Notifications"
    Accessible.role: Accessible.Button

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Notifications.doNotDisturb ? Icons.bellOff : Icons.bell
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
}
