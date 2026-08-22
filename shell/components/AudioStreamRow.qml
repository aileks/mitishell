import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Rectangle {
    id: root

    required property var node

    readonly property string label: AudioModel.streamLabel(node)
    readonly property real volume: node !== null && node.audio !== null
        ? AudioModel.clampVolume(node.audio.volume) : 0
    readonly property bool muted: node !== null && node.audio !== null
        ? node.audio.muted : false

    implicitWidth: 344
    implicitHeight: 64
    radius: Theme.radiusMedium
    color: activeFocus || hover.hovered ? Theme.overlay : "transparent"
    border.width: activeFocus ? 2 : 0
    border.color: Theme.blue
    activeFocusOnTab: true
    Accessible.name: label

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        Text {
            width: parent.width - percent.width - Theme.spaceSm
            text: root.label
            elide: Text.ElideRight
            color: root.muted ? Theme.red : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            IconButton {
                iconSource: root.muted
                    ? "../assets/icons/volume-x.svg"
                    : "../assets/icons/volume-2.svg"
                accessibleName: "Toggle " + root.label + " mute"
                onClicked: Audio.setStreamMuted(root.node, !root.muted)
            }

            ShellSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - parent.spacing
                value: root.volume
                Accessible.name: root.label + " volume"
                onMoved: Audio.setStreamVolume(root.node, value)
            }
        }
    }

    Text {
        id: percent

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        text: AudioModel.percent(root.volume) + "%"
        color: Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }

    HoverHandler {
        id: hover
    }
}
