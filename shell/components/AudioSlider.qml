import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Item {
    id: root

    required property string label
    required property string iconSource
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

        ShellSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 36 - parent.spacing
            value: root.currentValue
            Accessible.name: root.label + " volume"
            onMoved: root.volumeChanged(value)
        }
    }
}
