import QtQuick
import "../core"

// The bell island: unread count badge, opening the notifications page.
FocusScope {
    id: root

    required property var screen

    readonly property bool active: SurfaceCoordinator.activeKey === "control"
        && SurfaceCoordinator.originScreen === screen
        && Control.page === "notifications"

    implicitWidth: content.implicitWidth + Theme.spaceSm * 2
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.name: Notifications.unread > 0
        ? "Notifications, " + Notifications.unread + " unread" : "Notifications"
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    function activate() {
        Control.selectPage("notifications");
        SurfaceCoordinator.toggle("control", screen);
    }

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
        color: root.active || root.activeFocus || hover.hovered
            ? Theme.overlay
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.active ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.orange
        z: -1
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.activate()
    }

    Keys.onReturnPressed: function(event) {
        root.activate();
        event.accepted = true;
    }
    Keys.onSpacePressed: function(event) {
        root.activate();
        event.accepted = true;
    }
}
