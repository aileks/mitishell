import QtQuick
import "../core"
import "../lib/NetworkModel.js" as NetworkModel

Item {
    id: root
    required property var screen
    implicitHeight: content.implicitHeight

    readonly property bool ethernetAvailable: Network.ethernet !== null && Network.ethernet.available

    onVisibleChanged: if (visible) Network.refresh()

    Column {
        id: content
        width: parent.width
        spacing: Theme.spaceMd

        Text {
            text: "Network"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: Network.activeStation !== null
                ? Network.activeStation.ssid + " · " + Network.activeStation.signal + "%"
                : (root.ethernetAvailable && Network.ethernet.state === "connected"
                    ? "Ethernet connected" : "Disconnected")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
            elide: Text.ElideRight
        }

        ToggleRow {
            width: parent.width
            visible: Network.wifiAvailable
            accent: Theme.cyan
            label: "Wi-Fi"
            description: Network.wifiBusy
                ? "Changing Wi-Fi state"
                : (Network.wifiAvailable ? NetworkModel.stateLabel(Network.wifi.state) : "")
            checked: Network.wifiAvailable && Network.wifi.enabled
            enabled: !Network.wifiBusy
            onToggled: Network.setWifiEnabled(!checked)
        }

        InlineStatus {
            width: parent.width
            visible: Network.error !== ""
            message: Network.error
        }

        ActionButton {
            label: "More network controls"
            onActivated: {
                Control.selectPage("network");
                SurfaceCoordinator.open("settings", root.screen);
            }
        }
    }
}
