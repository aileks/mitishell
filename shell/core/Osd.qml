pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../lib/AudioModel.js" as AudioModel
import "../lib/DisplayModel.js" as DisplayModel
import "../lib/OsdModel.js" as OsdModel

QtObject {
    id: root

    property bool open: false
    property string kind: ""
    property string icon: ""
    property string message: ""
    property bool hasProgress: false
    property real progress: 0
    property string label: ""
    property int durationMS: 1200
    property color accent: Theme.orange

    readonly property string screenName: {
        const monitor = Hyprland.focusedMonitor;
        if (monitor !== null && monitor !== undefined) {
            return monitor.name;
        }
        const screens = Quickshell.screens;
        return screens !== undefined && screens.length > 0 ? screens[0].name : "";
    }

    function showState(state) {
        root.kind = state.kind || "generic";
        root.icon = state.icon || "";
        root.message = state.message || "";
        root.hasProgress = state.hasProgress === true;
        root.progress = Math.max(0, Math.min(1, Number(state.progress || 0)));
        root.label = state.label || "";
        root.durationMS = Math.round(Number(state.durationMS || 1200));
        root.accent = state.accent || Theme.orange;
        root.open = true;
        hideTimer.restart();
    }

    function showGeneric(icon, message, progressValue, durationValue) {
        const duration = Number(durationValue);
        const layout = OsdModel.genericLayout(message, progressValue);
        if (!Number.isFinite(duration) || duration < 250 || duration > 30000
                || (!icon && !layout.hasMessage && !layout.hasProgress)) {
            return false;
        }
        showState({
            kind: "generic",
            icon: String(icon || ""),
            message: layout.message,
            hasProgress: layout.hasProgress,
            progress: layout.progress,
            label: layout.label,
            durationMS: duration,
            accent: Theme.orange,
        });
        return true;
    }

    function showVolume() {
        const percent = AudioModel.percent(Audio.outputVolume);
        showState({
            kind: "volume",
            icon: OsdModel.iconFor("volume", percent, Audio.outputMuted),
            message: "",
            hasProgress: true,
            progress: Math.min(percent, 100) / 100,
            label: percent + "%",
            durationMS: 1200,
            accent: Theme.orange,
        });
    }

    function showMicVolume() {
        const percent = AudioModel.percent(Audio.inputVolume);
        showState({
            kind: "mic",
            icon: OsdModel.iconFor("mic", percent, Audio.inputMuted),
            message: "",
            hasProgress: true,
            progress: Math.min(percent, 100) / 100,
            label: percent + "%",
            durationMS: 1200,
            accent: Theme.orange,
        });
    }

    function showMicMuted(muted) {
        showState({
            kind: "mic",
            icon: muted ? "mic-off" : "mic",
            message: muted ? "Microphone muted" : "Microphone on",
            hasProgress: false,
            progress: 0,
            label: "",
            durationMS: 1200,
            accent: Theme.orange,
        });
    }

    function showBrightness() {
        showState({
            kind: "brightness",
            icon: "sun",
            message: "",
            hasProgress: true,
            progress: DisplayModel.progress(Display.brightness),
            label: DisplayModel.percentLabel(Display.brightness),
            durationMS: 1200,
            accent: Theme.orange,
        });
    }

    function showNightLight(enabled, temperatureKelvin) {
        showState({
            kind: "night-light",
            icon: "moon",
            message: enabled
                ? "Night light on"
                : "Night light off",
            hasProgress: false,
            progress: 0,
            label: "",
            durationMS: 1200,
            accent: Theme.orange,
        });
    }

    function showReminder(message) {
        showState({
            kind: "reminder",
            icon: "reminder",
            message: String(message || "Reminder updated"),
            hasProgress: false,
            progress: 0,
            label: "",
            durationMS: 1600,
            accent: Theme.pink,
        });
    }

    property Timer hideTimer: Timer {
        interval: root.durationMS
        onTriggered: root.open = false
    }
}
