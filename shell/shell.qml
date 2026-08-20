import QtQuick
import Quickshell
import Quickshell.Io
import "components"

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
}
