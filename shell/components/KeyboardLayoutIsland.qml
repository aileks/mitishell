import QtQuick
import "../core"

FocusScope {
    implicitWidth: label.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.name: "Keyboard layout " + KeyboardLayout.label + ", activate to cycle"
    Accessible.role: Accessible.Button
    Accessible.onPressAction: KeyboardLayout.cycle()

    Text {
        id: label
        anchors.centerIn: parent
        text: KeyboardLayout.label
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }
    Rectangle {
        anchors.fill: parent
        z: -1
        radius: Theme.radiusPill
        color: parent.activeFocus || hover.hovered ? Theme.hoverFill : "transparent"
        border.width: parent.activeFocus ? 2 : 0
        border.color: Theme.blue
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    }
    TapHandler { onTapped: KeyboardLayout.cycle() }
    Keys.onReturnPressed: function(event) { KeyboardLayout.cycle(); event.accepted = true; }
    Keys.onSpacePressed: function(event) { KeyboardLayout.cycle(); event.accepted = true; }
}
