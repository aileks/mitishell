import QtQuick
import "../core"

// A labeled switch row. The pill slides and fills the accent color when on.
FocusScope {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    // Orange for runtime controls, blue for configuration.
    property color accent: Theme.orange
    signal toggled

    implicitWidth: parent ? parent.width : 320
    implicitHeight: Math.max(copy.implicitHeight, toggle.height)
    activeFocusOnTab: true
    Accessible.name: label
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onPressAction: activate()

    function activate() {
        toggled();
    }

    Column {
        id: copy

        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs

        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Text {
            visible: root.description !== ""
            width: parent.width
            text: root.description
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeCaption
        }

    }

    Rectangle {
        id: toggle

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 24
        radius: Theme.radiusPill
        color: root.checked ? root.accent
            : (press.pressed ? Theme.pressedFill
                : (root.activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised))
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.blue
            : (root.checked ? root.accent : Theme.borderStrong)

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: Theme.radiusPill
            color: root.checked ? Theme.background : Theme.textBright

            Behavior on x {
                NumberAnimation {
                    duration: Motion.duration(Motion.quick)
                    easing.type: Motion.easingStandard
                }
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    }

    TapHandler {
        id: press
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
