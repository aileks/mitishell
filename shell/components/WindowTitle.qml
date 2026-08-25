import QtQuick
import Quickshell.Hyprland
import "../core"
import "../lib/WorkspaceModel.js" as WorkspaceModel

Text {
    id: root

    required property var screen
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var activeWorkspace: monitor === null ? null : monitor.activeWorkspace

    text: WorkspaceModel.windowTitle(activeWorkspace)
    color: Theme.text
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontSizeBody
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.duration(Motion.quick)
            easing.type: Motion.easingStandard
        }
    }
}
