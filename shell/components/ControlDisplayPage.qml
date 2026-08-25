import QtQuick
import "../core"

Flickable {
    id: root

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: content

        width: root.width
        spacing: Theme.spaceMd

        SurfaceHeader {
            width: parent.width
            title: "Display"
            accent: Theme.blue
        }

        Rectangle {
            width: parent.width
            visible: Display.available
            implicitHeight: masterContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: masterContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                Item {
                    width: parent.width
                    implicitHeight: brightnessLabel.implicitHeight

                    Text {
                        id: brightnessLabel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Brightness"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Display.brightness + "%"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                ShellSlider {
                    width: parent.width
                    from: 1
                    to: 100
                    stepSize: 1
                    value: Display.brightness
                    Accessible.name: "Brightness for all displays"
                    onMoved: Display.setBrightness(value)
                }

                Repeater {
                    model: Display.displays

                    delegate: Column {
                        id: displayEntry

                        required property var modelData

                        width: parent.width
                        spacing: Theme.spaceXs

                        Text {
                            text: displayEntry.modelData.connector
                            color: Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeCaption
                        }

                        ShellSlider {
                            width: parent.width
                            from: 1
                            to: 100
                            stepSize: 1
                            value: displayEntry.modelData.brightness
                            Accessible.name: "Brightness for " + displayEntry.modelData.connector
                            onMoved: Display.setConnectorBrightness(
                                displayEntry.modelData.connector, value)
                        }
                    }
                }
            }
        }

        InlineStatus {
            width: parent.width
            visible: !Display.available
            message: Display.error !== ""
                ? Display.error
                : "No displays with brightness control"
        }
    }
}
