import QtQuick
import "../core"

FocusScope {
    id: root

    property string iconSource: ""
    property color accent: Theme.orange
    // Buttons whose action is a persistent shell state (dnd, night light,
    // mic mute) keep an accent tint while that state is on.
    property bool activeState: false
    required property string accessibleName
    signal activated

    implicitWidth: 24
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
    Accessible.onPressAction: activate()

    function activate() { activated(); }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.activeState || root.activeFocus || hover.hovered
            ? Theme.alpha(root.accent, 0.14) : "transparent"
        border.width: root.activeFocus ? 2 : (root.activeState ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : root.accent

        IconLabel {
            anchors.centerIn: parent
            visible: root.iconSource !== ""
            value: root.iconSource
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.activate() }
    }

    Keys.onReturnPressed: function(event) { root.activate(); event.accepted = true; }
    Keys.onSpacePressed: function(event) { root.activate(); event.accepted = true; }
}
