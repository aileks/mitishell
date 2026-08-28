import QtQuick
import "../core"

Column {
    id: root

    property bool showVolume: true
    readonly property bool wifiAvailable: Network.wifiAvailable

    spacing: Theme.spaceSm

    onVisibleChanged: {
        if (!visible) return;
        Network.refresh();
        Display.refresh();
    }

    AudioSlider {
        width: parent.width
        visible: root.showVolume
        label: "Volume"
        iconSource: Audio.outputMuted
            ? "../assets/icons/volume-x.svg"
            : "../assets/icons/volume-2.svg"
        currentValue: Audio.outputVolume
        onVolumeChanged: function(value) { Audio.setOutputVolume(value); }
        onMuteRequested: Audio.toggleOutputMute()
    }

    BrightnessControl {
        width: parent.width
        visible: Display.available
        accessibleName: "Brightness"
    }

    ToggleRow {
        width: parent.width
        visible: root.wifiAvailable
        accent: Theme.cyan
        label: "Wi-Fi"
        description: Network.wifiBusy ? "Changing Wi-Fi state" : ""
        checked: root.wifiAvailable && Network.wifi.enabled
        enabled: !Network.wifiBusy
        onToggled: Network.setWifiEnabled(!checked)
    }

    ToggleRow {
        width: parent.width
        label: "Do not disturb"
        checked: Notifications.doNotDisturb
        onToggled: Notifications.toggleDoNotDisturb()
    }

    ToggleRow {
        width: parent.width
        visible: NightLight.available
        label: "Night light"
        description: NightLight.description
        checked: NightLight.enabled
        enabled: !NightLight.busy
        onToggled: NightLight.toggle()
    }
}
