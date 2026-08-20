import QtQuick
import "../core"

FocusScope {
    id: root

    required property url iconSource
    required property string accessibleName
    signal clicked

    implicitWidth: 36
    implicitHeight: 36
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
        color: root.activeFocus || hover.hovered ? Theme.overlay : "transparent"
        opacity: root.enabled ? 1 : 0.35

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: root.iconSource
            sourceSize.width: 18
            sourceSize.height: 18
        }

        HoverHandler {
            id: hover
        }
    }

    TapHandler {
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
