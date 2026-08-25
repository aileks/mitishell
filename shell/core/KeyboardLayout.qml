pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../lib/KeyboardLayoutModel.js" as LayoutModel

QtObject {
    id: root

    property var layouts: []
    property string activeDescription: ""
    property string activeCode: ""
    property var descriptions: ({})
    readonly property bool available: layouts.length > 1
    readonly property string label: (activeCode || activeDescription || "??").toUpperCase()

    function resolveCode() {
        activeCode = LayoutModel.codeForDescription(layouts, activeDescription, descriptions);
    }

    function refresh() {
        if (!layoutProbe.running) layoutProbe.running = true;
        if (!deviceProbe.running) deviceProbe.running = true;
    }

    function cycle() {
        if (available && !cycleProcess.running) cycleProcess.running = true;
    }

    property FileView rules: FileView {
        path: "/usr/share/X11/xkb/rules/base.lst"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.descriptions = LayoutModel.layoutDescriptions(text());
            root.resolveCode();
        }
    }

    property Process layoutProbeProcess: Process {
        id: layoutProbe
        command: ["hyprctl", "-j", "getoption", "input:kb_layout"]
        stdout: StdioCollector { id: layoutOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: {
            // qmllint enable signal-handler-parameters
            root.layouts = LayoutModel.layoutsFromOption(layoutOutput.text);
            root.resolveCode();
        }
    }

    property Process deviceProbeProcess: Process {
        id: deviceProbe
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector { id: deviceOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: {
            // qmllint enable signal-handler-parameters
            root.activeDescription = LayoutModel.activeKeymap(deviceOutput.text);
            root.resolveCode();
        }
    }

    property Process cycleLayoutProcess: Process {
        id: cycleProcess
        command: ["hyprctl", "switchxkblayout", "current", "next"]
        // qmllint disable signal-handler-parameters
        onExited: root.refresh()
        // qmllint enable signal-handler-parameters
    }

    property Connections hyprlandEvents: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = LayoutModel.eventParts(event.data);
                if (parts.length === 2) {
                    root.activeDescription = parts[1];
                    root.resolveCode();
                }
            } else if (event.name === "configreloaded") {
                root.refresh();
            }
        }
    }

    Component.onCompleted: refresh()
}
