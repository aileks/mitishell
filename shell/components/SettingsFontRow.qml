pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/FontModel.js" as FontModel

// One clickable font setting: opens the font picker layered over the
// settings card. The value shows the active family or its default.
Column {
    id: root

    required property string label
    // Which picker this row opens: "standard" or "mono".
    required property string slot
    required property string value

    readonly property string fieldKey: FontModel.slotDescriptor(slot).fieldKey
    readonly property string error: Settings.fieldErrors[fieldKey] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    function open() {
        Fonts.openPicker(root.slot);
    }

    Rectangle {
        id: row

        width: parent.width
        height: Theme.controlHeight
        radius: Theme.radiusMedium
        color: rowPress.pressed ? Theme.pressedFill
            : (row.activeFocus || rowHover.hovered ? Theme.hoverFill : "transparent")
        border.width: row.activeFocus ? 2 : 0
        border.color: Theme.blue
        activeFocusOnTab: true
        Accessible.name: root.label + ": " + root.value
        Accessible.role: Accessible.Button
        Accessible.onPressAction: root.open()

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceMd
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceMd
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceSm

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, row.width * 0.45)
                text: root.value
                color: Theme.textMuted
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
            }

            IconLabel {
                anchors.verticalCenter: parent.verticalCenter
                value: Icons.chevronRight
            }
        }

        HoverHandler {
            id: rowHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: rowPress

            onTapped: root.open()
        }

        Keys.onReturnPressed: function(event) {
            root.open();
            event.accepted = true;
        }
        Keys.onSpacePressed: function(event) {
            root.open();
            event.accepted = true;
        }
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }
}
