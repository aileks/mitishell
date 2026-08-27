import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Rectangle {
    id: root

    required property var stream

    // The first node with a bound audio object carries the group's display
    // state; writes go to every node through the Audio service.
    readonly property var node: {
        for (let index = 0; index < stream.nodes.length; index++) {
            if (stream.nodes[index].audio !== null) {
                return stream.nodes[index];
            }
        }
        return null;
    }
    readonly property real volume: node !== null
        ? AudioModel.clampVolume(node.audio.volume) : 0
    readonly property bool muted: node !== null ? node.audio.muted : false

    implicitWidth: 344
    implicitHeight: 64
    radius: Theme.radiusMedium
    color: activeFocus || hover.hovered ? Theme.hoverFill : "transparent"
    border.width: activeFocus ? 2 : 0
    border.color: Theme.blue
    activeFocusOnTab: true
    Accessible.name: stream.label

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        Text {
            width: parent.width - percent.width - Theme.spaceSm
            text: root.stream.label
            elide: Text.ElideRight
            color: Theme.text
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
                accessibleName: "Toggle " + root.stream.label + " mute"
                onClicked: Audio.setStreamMuted(root.stream, !root.muted)
            }

            ShellSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - parent.spacing
                from: 0
                to: AudioModel.maximumVolume
                stepSize: 0.01
                value: root.volume
                Accessible.name: root.stream.label + " volume"
                onMoved: Audio.setStreamVolume(root.stream, value)
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
