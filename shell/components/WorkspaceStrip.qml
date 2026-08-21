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
        model: WorkspaceModel.idsForMonitor(Hyprland.workspaces.values, root.screen.name)

        delegate: Rectangle {
            id: workspaceItem

            required property int modelData
            readonly property var workspace: root.workspaceById(modelData)
            readonly property bool occupied: workspace !== null
                && workspace.toplevels.values.length > 0
            readonly property bool active: workspace !== null && workspace.active
            readonly property bool urgent: workspace !== null && workspace.urgent

            width: active ? 30 : 24
            height: 24
            radius: Theme.radiusPill
            color: urgent ? Theme.red : (active ? Theme.orange : "transparent")
            border.width: activeFocus ? 2 : (!active && occupied ? 1 : 0)
            border.color: activeFocus ? Theme.blue : Theme.overlay
            activeFocusOnTab: true

            Behavior on width {
                NumberAnimation {
                    duration: Motion.duration(Motion.normal)
                    easing.type: Easing.OutCubic
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

            TapHandler {
                onTapped: {
                    if (workspaceItem.workspace !== null) {
                        workspaceItem.workspace.activate();
                    }
                }
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
