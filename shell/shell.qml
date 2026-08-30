import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "core"
import "lib/AudioModel.js" as AudioModel

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: BarHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: OsdHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: ControlHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: PowerHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: ReminderHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: EmojiHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: LauncherHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: KeybindingsHost {}
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

        function dnd(): string {
            Notifications.toggleDoNotDisturb();
            return "do not disturb toggled";
        }
    }

    IpcHandler {
        target: "osd"

        function show(icon: string, message: string, progress: string, duration: string): string {
            return Osd.showGeneric(icon, message, progress, duration)
                ? "OSD shown"
                : "OSD invalid";
        }
    }

    IpcHandler {
        target: "reminders"

        function open(): string {
            const screen = root.focusedScreen();
            if (screen === null) {
                return "Reminder overlay unavailable";
            }
            Reminders.refresh();
            SurfaceCoordinator.toggle("reminders", screen);
            return "Reminder overlay opened";
        }

        function changed(message: string): string {
            Reminders.refresh();
            Osd.showReminder(message);
            return "Reminder state refreshed";
        }
    }

    IpcHandler {
        target: "emoji"

        function toggle(): string {
            const screen = root.focusedScreen();
            if (screen === null) {
                return "emoji picker unavailable";
            }
            SurfaceCoordinator.toggle("emoji", screen);
            return "emoji picker toggled";
        }
    }

    IpcHandler {
        target: "clipboard"

        function open(): string {
            const screen = root.focusedScreen();
            if (screen === null) {
                return "clipboard history unavailable";
            }
            Launcher.openWithQuery(":", screen);
            return "clipboard opened";
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): string {
            const screen = root.focusedScreen();
            if (screen === null) return "launcher unavailable";
            SurfaceCoordinator.toggle("launcher", screen);
            return "launcher toggled";
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): string {
            const screen = root.focusedScreen();
            if (screen === null) return "keybind viewer unavailable";
            SurfaceCoordinator.toggle("keybinds", screen);
            return "keybinds toggled";
        }
    }

    IpcHandler {
        target: "bluetooth"

        function pairRequest(payload: string): string {
            Bluetooth.handlePairRequest(payload);
            return "pair request shown";
        }
    }

    IpcHandler {
        target: "power"

        function open(): string {
            const screen = root.focusedScreen();
            if (screen === null) {
                return "power menu unavailable";
            }
            SurfaceCoordinator.toggle("power", screen);
            return "power menu opened";
        }
    }

    IpcHandler {
        target: "settings"

        function open(): string {
            const screen = root.focusedScreen();
            if (screen === null) {
                return "settings unavailable";
            }
            Control.selectPage("overview");
            SurfaceCoordinator.open("settings", screen);
            return "settings opened";
        }

        function toggle(page: string): string {
            const screen = root.focusedScreen();
            if (screen === null) return "settings unavailable";
            Control.selectPage(page);
            SurfaceCoordinator.toggle("settings", screen);
            return "settings toggled";
        }
    }

    IpcHandler {
        target: "audio"

        function volume(action: string): string {
            if (!Audio.ready) {
                return "volume unavailable";
            }
            if (action === "up" || action === "down") {
                // Keybind steps cap at 100 percent and always unmute, so a
                // step from silence is heard and the OSD scale holds.
                const delta = action === "up" ? 0.05 : -0.05;
                Audio.setOutputMuted(false);
                Audio.setOutputVolume(
                    AudioModel.stepVolumeWithin(Audio.outputVolume, delta, 1));
            } else if (action === "mute") {
                Audio.toggleOutputMute();
            } else {
                return "volume action invalid";
            }
            Osd.showVolume();
            return "volume updated";
        }

        function volumeSet(value: string): string {
            if (!Audio.ready) {
                return "volume unavailable";
            }
            const percent = parseInt(value, 10);
            if (isNaN(percent) || percent < 0 || percent > 150) {
                return "volume value invalid";
            }
            Audio.setOutputMuted(false);
            Audio.setOutputVolume(percent / 100);
            Osd.showVolume();
            return "volume updated";
        }

        function mic(action: string): string {
            if (!Audio.ready) {
                return "microphone unavailable";
            }
            if (action === "up" || action === "down") {
                const delta = action === "up" ? 0.05 : -0.05;
                Audio.setInputMuted(false);
                Audio.setInputVolume(
                    AudioModel.stepVolumeWithin(Audio.inputVolume, delta, 1));
                Osd.showMicVolume();
            } else if (action === "mute") {
                Audio.toggleInputMute();
                Osd.showMicMuted(Audio.inputMuted);
            } else {
                return "microphone action invalid";
            }
            return "microphone updated";
        }

        function micSet(value: string): string {
            if (!Audio.ready) {
                return "microphone unavailable";
            }
            const percent = parseInt(value, 10);
            if (isNaN(percent) || percent < 0 || percent > 150) {
                return "microphone value invalid";
            }
            Audio.setInputMuted(false);
            Audio.setInputVolume(percent / 100);
            Osd.showMicVolume();
            return "microphone updated";
        }
    }

    IpcHandler {
        target: "display"

        function brightness(action: string): string {
            if (!Display.available) {
                return "brightness unavailable";
            }
            if (action === "up") {
                Display.stepBrightness(5);
            } else if (action === "down") {
                Display.stepBrightness(-5);
            } else {
                return "brightness action invalid";
            }
            Osd.showBrightness();
            return "brightness updated";
        }

        function brightnessSet(value: string): string {
            if (!Display.available) {
                return "brightness unavailable";
            }
            const percent = parseInt(value, 10);
            if (isNaN(percent) || percent < 0 || percent > 100) {
                return "brightness value invalid";
            }
            Display.setBrightness(percent);
            Osd.showBrightness();
            return "brightness updated";
        }
    }

    IpcHandler {
        target: "control"

        function toggle(page: string): string {
            const target = root.focusedScreen();
            if (target === null) {
                return "control center unavailable";
            }
            // Legacy aliases must match runLegacyControlAction in cli.go.
            const renamed = page === "home" ? "overview"
                : (page === "settings" ? "system" : page);
            Control.selectPage(renamed);
            SurfaceCoordinator.toggle("settings", target);
            return "control center toggled";
        }
    }

    // Display has no bar widget that would instantiate it at startup, but its
    // discovery needs to run before the first brightness call arrives.
    Component.onCompleted: Display.refresh()

    // HyprlandSync only watches events; referencing it here instantiates
    // the singleton at startup so the resync covers the whole session.
    readonly property bool hyprlandSyncWatched: HyprlandSync.resyncPending

    function focusedScreen() {
        const screens = Quickshell.screens !== undefined ? Quickshell.screens : [];
        for (let index = 0; index < screens.length; index++) {
            if (screens[index].name === Osd.screenName) {
                return screens[index];
            }
        }
        return screens.length > 0 ? screens[0] : null;
    }
}
