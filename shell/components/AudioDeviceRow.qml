import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Rectangle {
    id: root

    required property var node
    required property bool selected
    signal chosen

    implicitWidth: 344
    implicitHeight: 40
    radius: Theme.radiusMedium
    color: selected ? Theme.orange : (activeFocus || hover.hovered ? Theme.overlay : "transparent")
    border.width: activeFocus ? 2 : 0
    border.color: Theme.blue
    activeFocusOnTab: true
    Accessible.name: AudioModel.deviceLabel(node)
    Accessible.role: Accessible.RadioButton
    Accessible.checked: selected
    Accessible.onPressAction: chosen()

    Text {
        anchors.left: parent.left
        anchors.right: status.left
        anchors.leftMargin: Theme.spaceMd
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        text: AudioModel.deviceLabel(root.node)
        elide: Text.ElideRight
        color: root.selected ? Theme.background : Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        id: status

        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        text: root.selected ? "active" : ""
        color: root.selected ? Theme.background : Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }

    HoverHandler {
        id: hover
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
