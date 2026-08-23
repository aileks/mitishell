import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "core"
import "lib/AudioModel.js" as AudioModel

ShellRoot {
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

        delegate: NotificationsPopupHost {}
    }

    Variants {
        model: Quickshell.screens

        delegate: PowerHost {}
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
        target: "bluetooth"

        function pairRequest(payload: string): string {
            Bluetooth.handlePairRequest(payload);
            return "pair request shown";
        }
    }

    IpcHandler {
        target: "power"

        function open(): string {
            const screen = focusedScreen();
            if (screen === null) {
                return "power menu unavailable";
            }
            SurfaceCoordinator.toggle("power", screen);
            return "power menu opened";
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
            const target = focusedScreen();
            if (target === null) {
                return "control center unavailable";
            }
            Control.selectPage(page);
            SurfaceCoordinator.toggle("control", target);
            return "control center toggled";
        }
    }

    // Display has no island that would instantiate it at startup, but its
    // discovery needs to run before the first brightness call arrives.
    Component.onCompleted: Display.refresh()

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
