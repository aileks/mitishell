pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"
import "../lib/BluetoothModel.js" as BluetoothModel

Flickable {
    id: root

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: {
        if (visible) {
            Bluetooth.refresh();
            pollTimer.restart();
        } else {
            pollTimer.stop();
        }
    }

    property Timer pollTimer: Timer {
        interval: 4000
        repeat: true
        onTriggered: Bluetooth.refresh()
    }

    Column {
        id: content

        width: root.width
        spacing: Theme.spaceMd

        SurfaceHeader {
            width: parent.width
            title: "Bluetooth"
            description: "Nearby and saved devices"
            accent: Theme.cyan
        }

        Text {
            width: parent.width
            visible: Bluetooth.error !== ""
            text: Bluetooth.error
            wrapMode: Text.Wrap
            color: Theme.red
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        // Active pairing prompt.
        Rectangle {
            width: parent.width
            visible: Bluetooth.pairRequest !== null
            implicitHeight: pairContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container
            border.width: 1
            border.color: Theme.orange

            Column {
                id: pairContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                Text {
                    width: parent.width
                    visible: Bluetooth.pairRequest !== null
                    text: Bluetooth.pairRequest !== null
                        ? BluetoothModel.pairPromptLabel(Bluetooth.pairRequest) : ""
                    wrapMode: Text.Wrap
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }

                Controls.TextField {
                    id: pairEntry

                    width: parent.width
                    visible: Bluetooth.pairRequest !== null
                        && BluetoothModel.requestWantsText(Bluetooth.pairRequest)
                    placeholderText: "Passkey"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                    activeFocusOnTab: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.background
                        border.width: pairEntry.activeFocus ? 2 : 1
                        border.color: pairEntry.activeFocus ? Theme.blue : Theme.overlay
                    }

                    onAccepted: Bluetooth.respond(pairEntry.text)
                }

                Row {
                    visible: Bluetooth.pairRequest !== null
                        && !BluetoothModel.requestIsDisplayOnly(Bluetooth.pairRequest)
                    spacing: Theme.spaceSm

                    Rectangle {
                        width: confirmLabel.implicitWidth + Theme.spaceLg * 2
                        height: 30
                        radius: Theme.radiusPill
                        color: pairConfirmHover.hovered ? Theme.overlay : Theme.orange

                        Text {
                            id: confirmLabel

                            anchors.centerIn: parent
                            text: "Confirm"
                            color: Theme.background
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Font.DemiBold
                        }

                        HoverHandler {
                            id: pairConfirmHover
                        }

                        TapHandler {
                            onTapped: {
                                if (BluetoothModel.requestWantsText(Bluetooth.pairRequest)) {
                                    Bluetooth.respond(pairEntry.text);
                                } else {
                                    Bluetooth.respond("true");
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: denyLabel.implicitWidth + Theme.spaceLg * 2
                        height: 30
                        radius: Theme.radiusPill
                        color: pairDenyHover.hovered ? Theme.overlay : Theme.container
                        border.width: 1
                        border.color: Theme.overlay

                        Text {
                            id: denyLabel

                            anchors.centerIn: parent
                            text: "Deny"
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeCaption
                        }

                        HoverHandler {
                            id: pairDenyHover
                        }

                        TapHandler {
                            onTapped: Bluetooth.respond("false")
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            visible: Bluetooth.adapter !== null
            implicitHeight: adapterContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: adapterContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                Item {
                    width: parent.width
                    implicitHeight: adapterLabel.implicitHeight

                    Text {
                        id: adapterLabel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Adapter"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Bluetooth.adapter !== null && Bluetooth.adapter.discovering
                            ? "scanning" : ""
                        color: Theme.blue
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Scan for devices"
                    checked: Bluetooth.adapter !== null && Bluetooth.adapter.discovering
                    onToggled: Bluetooth.setDiscovering(
                        !(Bluetooth.adapter !== null && Bluetooth.adapter.discovering))
                }
            }
        }

        Text {
            width: parent.width
            visible: Bluetooth.devices.length === 0
            text: Bluetooth.adapter !== null && Bluetooth.adapter.discovering
                ? "Searching for devices" : "No devices"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Repeater {
            model: Bluetooth.devices

            delegate: Rectangle {
                id: deviceEntry

                required property var modelData

                width: parent.width
                implicitHeight: deviceContent.implicitHeight + Theme.spaceSm * 2
                radius: Theme.radiusMedium
                color: activeFocus || hover.hovered ? Theme.overlay : Theme.container
                border.width: activeFocus ? 2 : 0
                border.color: Theme.blue
                activeFocusOnTab: true
                Accessible.name: deviceEntry.modelData.name

                Column {
                    id: deviceContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    Item {
                        width: parent.width
                        implicitHeight: deviceName.implicitHeight

                        Text {
                            id: deviceName

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceEntry.modelData.name !== ""
                                ? deviceEntry.modelData.name : deviceEntry.modelData.address
                            elide: Text.ElideRight
                            width: parent.width - deviceStatus.width - Theme.spaceSm
                            color: deviceEntry.modelData.connected
                                ? Theme.textBright : Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: deviceEntry.modelData.connected ? Font.DemiBold : Font.Normal
                        }

                        Text {
                            id: deviceStatus

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                let parts = [BluetoothModel.deviceStatus(deviceEntry.modelData)];
                                if (deviceEntry.modelData.battery !== null
                                    && deviceEntry.modelData.battery !== undefined) {
                                    parts.push(deviceEntry.modelData.battery + "%");
                                }
                                return parts.join(" · ");
                            }
                            color: deviceEntry.modelData.connected
                                ? Theme.textBright : Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeCaption
                        }
                    }

                    Row {
                        spacing: Theme.spaceSm

                        Repeater {
                            model: BluetoothModel.deviceActions(deviceEntry.modelData)

                            delegate: Rectangle {
                                id: deviceAction

                                required property string modelData

                                width: actionText.implicitWidth + Theme.spaceLg * 2
                                height: 26
                                radius: Theme.radiusPill
                                color: actionHover.hovered || activeFocus
                                    ? Theme.overlay : "transparent"
                                border.width: activeFocus ? 2 : 1
                                border.color: activeFocus ? Theme.blue : Theme.overlay
                                activeFocusOnTab: true
                                Accessible.name: deviceAction.modelData
                                    + " " + deviceEntry.modelData.name
                                Accessible.role: Accessible.Button
                                Accessible.onPressAction: activated()

                                function activated() {
                                    Bluetooth.action(
                                        deviceAction.modelData, deviceEntry.modelData.address);
                                }

                                Text {
                                    id: actionText

                                    anchors.centerIn: parent
                                    text: deviceAction.modelData
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeCaption
                                }

                                HoverHandler {
                                    id: actionHover
                                }

                                TapHandler {
                                    onTapped: deviceAction.activated()
                                }

                                Keys.onReturnPressed: function(event) {
                                    deviceAction.activated();
                                    event.accepted = true;
                                }
                                Keys.onSpacePressed: function(event) {
                                    deviceAction.activated();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    id: hover
                }
            }
        }
    }
}
