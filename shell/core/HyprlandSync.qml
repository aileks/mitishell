pragma Singleton

import QtQuick
import Quickshell.Hyprland

// QuickShell's Hyprland models can lag behind compositor window events.
// Relevant events trigger one coalesced resync so occupancy and titles stay true.
QtObject {
    id: root

    property bool resyncPending: false
    readonly property var resyncEvents: [
        "activewindow",
        "activewindowv2",
        "windowtitle",
        "windowtitlev2",
        "openwindow",
        "closewindow",
        "movewindow",
        "workspace",
        "workspacev2",
        "focusedmon"
    ]

    property Connections hyprlandEvents: Connections {
        target: Hyprland

        // qmllint disable signal-handler-parameters
        function onRawEvent(event) {
            // qmllint enable signal-handler-parameters
            if (root.resyncEvents.indexOf(event.name) === -1) {
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
