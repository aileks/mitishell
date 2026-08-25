import QtQuick
import "../core"

FocusScope {
    id: root

    required property var screen

    readonly property bool active: SurfaceCoordinator.activeKey === "control"
        && SurfaceCoordinator.originScreen === screen

    implicitWidth: 22
    implicitHeight: 22
    activeFocusOnTab: true
    Accessible.name: "Toggle control center"
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    // Summoning from the bar always starts on the home page.
    function activate() {
        if (!active) {
            Control.selectPage("home");
        }
        SurfaceCoordinator.toggle("control", screen);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.active || root.activeFocus || hover.hovered
            ? Theme.overlay
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.active ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.orange

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: "../assets/icons/sliders.svg"
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
