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
            title: "Audio"
            accent: Theme.orange
        }

        AudioDeviceSections {
            width: parent.width
        }

        Rectangle {
            id: applicationsCard

            width: parent.width
            implicitHeight: applicationsContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: applicationsContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                Item {
                    width: parent.width
                    implicitHeight: applicationsLabel.implicitHeight

                    Text {
                        id: applicationsLabel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Applications"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.streams.length === 0
                            ? "" : String(Audio.streams.length)
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                Text {
                    width: parent.width
                    visible: Audio.streams.length === 0
                    text: "No applications are playing audio"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }

                Repeater {
                    model: Audio.streams

                    delegate: AudioStreamRow {
                        required property var modelData

                        width: parent.width
                        stream: modelData
                    }
                }
            }
        }
    }
}
