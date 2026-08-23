pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// One selectable settings chip: blue accent when active (configuration
// category), keyboard activatable.
Rectangle {
    id: root

    property string label: ""
    property bool checked: false
    signal chosen

    width: pillLabel.implicitWidth + Theme.spaceMd * 2
    height: 28
    radius: Theme.radiusPill
    color: root.checked ? Theme.overlay
        : (root.activeFocus || pillHover.hovered ? Theme.overlay : Theme.surface)
    border.width: root.activeFocus ? 2 : (root.checked ? 1 : 0)
    border.color: Theme.blue
    activeFocusOnTab: true
    Accessible.name: label
    Accessible.role: Accessible.Button
    Accessible.onPressAction: chosen()

    Text {
        id: pillLabel

        anchors.centerIn: parent
        text: root.label
        color: root.checked ? Theme.textBright : Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
        font.weight: root.checked ? Font.DemiBold : Font.Normal
    }

    HoverHandler {
        id: pillHover
    }

    TapHandler {
        onTapped: root.chosen()
    }

    Keys.onReturnPressed: function(event) {
        root.chosen();
        event.accepted = true;
    }
    Keys.onSpacePressed: function(event) {
        root.chosen();
        event.accepted = true;
    }
}
