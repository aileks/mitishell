import QtQuick
import "../core"

FocusScope {
    id: root

    property string iconSource: ""
    property color accent: Theme.orange
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
        color: root.activeFocus || hover.hovered ? Theme.alpha(root.accent, 0.14) : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.blue

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
