import QtQuick
import "../core"

FocusScope {
    id: root

    property url iconSource
    property string glyph: ""
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

        Image {
            anchors.centerIn: parent
            visible: root.iconSource.toString() !== ""
            width: 16
            height: 16
            source: root.iconSource
            sourceSize.width: 32
            sourceSize.height: 32
        }

        Text {
            anchors.centerIn: parent
            visible: root.glyph !== ""
            text: root.glyph
            color: root.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSm
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.activate() }
    }

    Keys.onReturnPressed: function(event) { root.activate(); event.accepted = true; }
    Keys.onSpacePressed: function(event) { root.activate(); event.accepted = true; }
}
