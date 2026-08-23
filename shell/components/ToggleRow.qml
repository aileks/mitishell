import QtQuick
import "../core"

// A labeled switch row. The pill slides and fills orange when on.
FocusScope {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled

    implicitWidth: parent ? parent.width : 320
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true
    Accessible.name: label
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onPressAction: activate()

    function activate() {
        toggled();
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
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

        Rectangle {
            width: 44
            height: 24
            radius: Theme.radiusPill
            color: root.checked ? Theme.orange
                : (root.activeFocus || hover.hovered ? Theme.overlay : Theme.container)
            border.width: root.activeFocus ? 2 : 1
            border.color: root.activeFocus ? Theme.blue : Theme.overlay

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
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                id: hover
            }
        }
    }

    TapHandler {
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
