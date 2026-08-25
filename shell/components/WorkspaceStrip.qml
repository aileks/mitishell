pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../core"
import "../lib/WorkspaceModel.js" as WorkspaceModel

Row {
    id: root

    required property var screen

    spacing: Theme.spaceXs

    function workspaceById(id) {
        const values = Hyprland.workspaces.values;
        for (let index = 0; index < values.length; index += 1) {
            if (values[index].id === id) {
                return values[index];
            }
        }
        return null;
    }

    Repeater {
        model: WorkspaceModel.idsForMonitor(
            Hyprland.workspaces.values,
            root.screen !== null ? root.screen.name : "",
        )

        delegate: FocusScope {
            id: workspaceItem

            required property int modelData
            readonly property var workspace: root.workspaceById(modelData)
            readonly property bool occupied: workspace !== null
                && workspace.toplevels.values.length > 0
            readonly property bool active: workspace !== null && workspace.active
            readonly property bool urgent: workspace !== null && workspace.urgent

            width: 30
            height: 24
            activeFocusOnTab: true

            Rectangle {
                id: pill

                anchors.centerIn: parent
                width: workspaceItem.active ? 30 : 24
                height: parent.height
                radius: Theme.radiusPill
                color: workspaceItem.urgent
                    ? Theme.red
                    : (workspaceItem.active ? Theme.orange : "transparent")
                border.width: workspaceItem.activeFocus
                    ? 2
                    : (!workspaceItem.active && workspaceItem.occupied ? 1 : 0)
                border.color: workspaceItem.activeFocus ? Theme.blue : Theme.borderStrong

                Behavior on width {
                    NumberAnimation {
                        duration: Motion.duration(Motion.normal)
                        easing.type: Motion.easingStandard
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: WorkspaceModel.label(workspaceItem.modelData)
                    color: workspaceItem.active || workspaceItem.urgent
                        ? Theme.background
                        : (workspaceItem.occupied ? Theme.textBright : Theme.textMuted)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: workspaceItem.active ? Font.DemiBold : Font.Normal
                }
            }

            TapHandler {
                onTapped: {
                    if (workspaceItem.workspace !== null) {
                        workspaceItem.workspace.activate();
                    }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Keys.onReturnPressed: function(event) {
                if (workspaceItem.workspace !== null) {
                    workspaceItem.workspace.activate();
                }
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                if (workspaceItem.workspace !== null) {
                    workspaceItem.workspace.activate();
                }
                event.accepted = true;
            }
        }
    }
}
