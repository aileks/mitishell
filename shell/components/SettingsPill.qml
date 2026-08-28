pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// One selectable settings chip: blue accent when active (configuration
// category), keyboard activatable.
Rectangle {
    id: root

    property string label: ""
    property string fontFamily: Theme.fontSans
    property bool checked: false
    signal chosen

    width: pillLabel.implicitWidth + Theme.spaceMd * 2
    height: Theme.controlHeightSm
    radius: Theme.radiusPill
    color: root.checked ? Theme.alpha(Theme.blue, 0.22)
        : (pillPress.pressed ? Theme.pressedFill
            : (root.activeFocus || pillHover.hovered ? Theme.hoverFill : Theme.layerInset))
    border.width: root.activeFocus ? 2 : 1
    border.color: root.activeFocus || root.checked ? Theme.blue : Theme.borderStrong
    activeFocusOnTab: true
    Accessible.name: label
    Accessible.role: Accessible.Button
    Accessible.onPressAction: chosen()

    Text {
        id: pillLabel

        anchors.centerIn: parent
        text: root.label
        color: root.checked ? Theme.textBright : Theme.text
        font.family: root.fontFamily
        font.pixelSize: Theme.fontSizeCaption
        font.weight: root.checked ? Font.DemiBold : Font.Normal
    }

    HoverHandler {
        id: pillHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: pillPress
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
