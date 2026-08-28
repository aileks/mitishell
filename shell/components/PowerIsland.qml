import QtQuick
import "../core"

// The power island opens the native power menu on this output.
FocusScope {
    id: root

    required property var screen

    readonly property bool active: SurfaceCoordinator.activeKey === "power"
        && SurfaceCoordinator.originScreen === screen

    implicitWidth: 16 + Theme.islandPadding
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.name: "Open power menu"
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    function activate() {
        SurfaceCoordinator.toggle("power", screen);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.active || root.activeFocus || hover.hovered
            ? Theme.hoverFill
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.active ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.orange

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: "../assets/icons/power.svg"
            sourceSize.width: 16
            sourceSize.height: 16
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
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
