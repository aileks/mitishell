import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"
import "../lib/AudioModel.js" as AudioModel

Item {
    id: root

    required property string label
    required property url iconSource
    required property real currentValue
    signal volumeChanged(real value)
    signal muteRequested

    implicitWidth: 344
    implicitHeight: 58

    Text {
        id: label

        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        text: AudioModel.percent(root.currentValue) + "%"
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 36
        spacing: Theme.spaceSm

        IconButton {
            iconSource: root.iconSource
            accessibleName: "Toggle " + root.label.toLowerCase() + " mute"
            onClicked: root.muteRequested()
        }

        Controls.Slider {
            id: slider

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 36 - parent.spacing
            from: 0
            to: AudioModel.maximumVolume
            stepSize: 0.01
            value: root.currentValue
            Accessible.name: root.label + " volume"
            onMoved: root.volumeChanged(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 5
                radius: 3
                color: Theme.overlay

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Theme.orange
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition
                    * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: 7
                color: slider.activeFocus ? Theme.blue : Theme.textBright
            }
        }
    }
}
