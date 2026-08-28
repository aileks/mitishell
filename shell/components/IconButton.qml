import QtQuick
import "../core"

FocusScope {
    id: root

    required property string iconSource
    required property string accessibleName
    signal clicked

    implicitWidth: Theme.controlHeight
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: enabled
    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    function activate() {
        if (enabled) {
            clicked();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: press.pressed ? Theme.pressedFill
            : (root.activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised)
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.blue : Theme.borderStrong
        opacity: root.enabled ? 1 : 0.35

        IconLabel {
            anchors.centerIn: parent
            value: root.iconSource
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
    }

    TapHandler {
        id: press
        enabled: root.enabled
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
