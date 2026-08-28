pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Rectangle {
    id: root

    required property string label
    required property string iconSource
    required property real currentValue
    required property var devices
    required property var selectedDevice
    required property string emptyMessage

    signal volumeChanged(real value)
    signal muteRequested
    signal deviceChosen(var device)

    implicitHeight: sectionContent.implicitHeight + Theme.spaceMd * 2
    radius: Theme.radiusMedium
    color: Theme.container

    Column {
        id: sectionContent

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceSm

        AudioSlider {
            width: parent.width
            label: root.label
            iconSource: root.iconSource
            currentValue: root.currentValue
            onVolumeChanged: function(value) { root.volumeChanged(value); }
            onMuteRequested: root.muteRequested()
        }

        Text {
            text: "Device"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: root.devices.length === 0
            text: root.emptyMessage
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Flickable {
            id: deviceList

            width: parent.width
            height: Math.min(
                deviceRows.implicitHeight,
                Theme.controlHeightLg * 3 + Theme.spaceXs * 2,
            )
            visible: root.devices.length > 0
            contentWidth: width
            contentHeight: deviceRows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                blocking: false
                onWheel: function(event) {
                    const delta = event.pixelDelta.y !== 0
                        ? event.pixelDelta.y : event.angleDelta.y / 2;
                    const nextContentY = Math.max(
                        0,
                        Math.min(
                            deviceList.contentHeight - deviceList.height,
                            deviceList.contentY - delta,
                        ),
                    );
                    event.accepted = nextContentY !== deviceList.contentY;
                    if (event.accepted) {
                        deviceList.contentY = nextContentY;
                    }
                }
            }

            Column {
                id: deviceRows

                width: parent.width
                spacing: Theme.spaceXs

                Repeater {
                    model: root.devices

                    delegate: AudioDeviceRow {
                        required property var modelData
                        width: deviceRows.width
                        node: modelData
                        selected: root.selectedDevice === modelData
                        onChosen: root.deviceChosen(modelData)
                    }
                }
            }
        }
    }
}
