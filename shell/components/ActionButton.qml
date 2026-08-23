import QtQuick
import "../core"

FocusScope {
    id: root

    property string label: ""
    property url iconSource: ""
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
            : (root.selected ? root.accent : Theme.borderSubtle)
        opacity: root.enabled ? 1 : 0.38

        Row {
            id: content

            anchors.centerIn: parent
            spacing: Theme.spaceSm

            Image {
                visible: root.iconSource.toString() !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSm
                height: Theme.iconSm
                source: root.iconSource
                sourceSize.width: width
                sourceSize.height: height
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: root.destructive ? Theme.red : Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
                font.weight: root.selected ? Font.DemiBold : Font.Normal
            }
        }

        HoverHandler { id: hover }
        TapHandler { id: press; onTapped: root.activate() }
    }

    Keys.onReturnPressed: function(event) { root.activate(); event.accepted = true; }
    Keys.onSpacePressed: function(event) { root.activate(); event.accepted = true; }
}
