pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/BluetoothModel.js" as BluetoothModel

Item {
    id: root
    required property var screen
    implicitHeight: content.implicitHeight

    readonly property var quickDevices: Bluetooth.devices
        .filter(function(device) { return device.connected || (device.paired && device.inRange); })
        .sort(function(left, right) {
            if (left.connected !== right.connected) return left.connected ? -1 : 1;
            return String(left.name || left.address).localeCompare(String(right.name || right.address));
        })
    readonly property int hiddenCount: Math.max(0, quickDevices.length - 5)

    onVisibleChanged: if (visible) Bluetooth.refresh()

    Column {
        id: content
        width: parent.width
        spacing: Theme.spaceMd

        Text {
            text: "Bluetooth"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.quickDevices.length === 0
            text: "No connected or paired devices in range"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Repeater {
            model: root.quickDevices.slice(0, 5)
            delegate: Item {
                id: deviceRow
                required property var modelData
                width: content.width
                height: Theme.controlHeight

                Column {
                    anchors.left: parent.left
                    anchors.right: action.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Theme.spaceSm
                    spacing: 1
                    Text {
                        width: parent.width
                        text: deviceRow.modelData.name || deviceRow.modelData.address
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }
                    Text {
                        text: BluetoothModel.deviceStatus(deviceRow.modelData)
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                ActionButton {
                    id: action
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 100
                    height: Theme.controlHeightSm
                    label: deviceRow.modelData.connected ? "Disconnect" : "Connect"
                    enabled: !Bluetooth.actionRunning
                    onActivated: Bluetooth.action(
                        deviceRow.modelData.connected ? "disconnect" : "connect",
                        deviceRow.modelData.address)
                }
            }
        }

        Text {
            visible: root.hiddenCount > 0
            text: "+" + root.hiddenCount + " more in Settings"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeCaption
        }

        InlineStatus { width: parent.width; visible: Bluetooth.error !== ""; message: Bluetooth.error }

        ActionButton {
            label: "Manage devices"
            onActivated: {
                Control.selectPage("bluetooth");
                SurfaceCoordinator.open("settings", root.screen);
            }
        }
    }
}
