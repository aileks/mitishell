pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../lib/AudioModel.js" as AudioModel
import "../lib/DisplayModel.js" as DisplayModel

QtObject {
    id: root

    // Transient on-screen display state shared by every per-screen surface;
    // only the surface on the focused output is shown.

    property bool open: false
    property string kind: ""
    property string message: ""
    property real progress: 0
    property string label: ""

    readonly property bool barVisible: message === ""
    readonly property bool muted: kind === "mic"
        ? Audio.inputMuted
        : kind === "volume" && Audio.outputMuted

    readonly property string screenName: {
        const monitor = Hyprland.focusedMonitor;
        if (monitor !== null && monitor !== undefined) {
            return monitor.name;
        }
        const screens = Quickshell.screens;
        return screens !== undefined && screens.length > 0 ? screens[0].name : "";
    }

    function reveal(kind, progress, label, message) {
        // State is assigned before opening so a fresh OSD starts at its new
        // value; only updates while it remains open animate the bar.
        root.kind = kind;
        root.progress = progress;
        root.label = label;
        root.message = message;
        root.open = true;
        hideTimer.restart();
    }

    function showVolume() {
        const percent = AudioModel.percent(Audio.outputVolume);
        reveal("volume", Math.min(percent, 100) / 100, percent + "%", "");
    }

    function showMicVolume() {
        const percent = AudioModel.percent(Audio.inputVolume);
        reveal("mic", Math.min(percent, 100) / 100, percent + "%", "");
    }

    function showMicMuted(muted) {
        reveal("mic", 0, "", muted ? "Microphone muted" : "Microphone on");
    }

    function showBrightness() {
        reveal(
            "brightness",
            DisplayModel.progress(Display.brightness),
            DisplayModel.percentLabel(Display.brightness),
            "");
    }

    property Timer hideTimer: Timer {
        interval: 1200
        onTriggered: root.open = false
    }
}
