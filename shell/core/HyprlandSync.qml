pragma Singleton

import QtQuick
import Quickshell.Hyprland

// QuickShell's Hyprland models can drift when a window closes or crashes
// on an unfocused workspace; closewindow events trigger a resync so bar
// occupancy and titles stay true.
QtObject {
    id: root

    property bool resyncPending: false

    property Connections hyprlandEvents: Connections {
        target: Hyprland

        // qmllint disable signal-handler-parameters
        function onRawEvent(event) {
            // qmllint enable signal-handler-parameters
            if (event.name !== "closewindow") {
                return;
            }
            // Coalesce bursts so closing several windows at once triggers
            // one resync pass.
            if (root.resyncPending) {
                return;
            }
            root.resyncPending = true;
            Qt.callLater(function() {
                root.resyncPending = false;
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            });
        }
    }
}
