import QtQuick
import "../core"

FocusScope {
    id: root

    property string label: ""
    property string iconSource: ""
    property color accent: Theme.orange
    property bool selected: false
    property bool destructive: false
    signal activated

    implicitWidth: Math.max(88, content.implicitWidth + Theme.spaceLg * 2)
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: enabled
    Accessible.name: label
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    function activate() {
        if (enabled) {
            activated();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: root.selected ? Theme.alpha(root.accent, 0.22)
            : (press.pressed ? Theme.pressedFill
                : (root.activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised))
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.blue
            : (root.selected || root.destructive ? root.accent : Theme.borderStrong)
        opacity: root.enabled ? 1 : 0.38

        Row {
            id: content

            anchors.centerIn: parent
            spacing: Theme.spaceSm

            IconLabel {
                visible: root.iconSource !== ""
                anchors.verticalCenter: parent.verticalCenter
                value: root.iconSource
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
                font.weight: root.selected ? Font.DemiBold : Font.Normal
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: press; onTapped: root.activate() }
    }

    Keys.onReturnPressed: function(event) { root.activate(); event.accepted = true; }
    Keys.onSpacePressed: function(event) { root.activate(); event.accepted = true; }
}
