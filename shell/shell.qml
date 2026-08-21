//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "core"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: BarHost {}
    }

    IpcHandler {
        target: "shell"

        function ping(): string {
            return "pong";
        }

        function reload(): string {
            Qt.callLater(function() {
                Quickshell.reload(true);
            });
            return "reload requested";
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): string {
            return CompatibilityActions.toggleNotifications()
                ? "notifications toggled" : "notifications unavailable";
        }
    }

    IpcHandler {
        target: "power"

        function open(): string {
            return CompatibilityActions.openPowerMenu()
                ? "power menu opened" : "power menu unavailable";
        }
    }
}
