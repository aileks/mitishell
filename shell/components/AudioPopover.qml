import QtQuick
import "../core"

Item {
    id: root

    required property var screen

    implicitHeight: content.implicitHeight

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.spaceMd

        Text {
            text: "Audio"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        AudioSection {
            width: parent.width
            label: "Output"
            iconSource: Audio.outputMuted
                ? "../assets/icons/volume-x.svg"
                : "../assets/icons/volume-2.svg"
            currentValue: Audio.outputVolume
            devices: Audio.sinks
            selectedDevice: Audio.output
            emptyMessage: "No output devices"
            onVolumeChanged: function(value) { Audio.setOutputVolume(value); }
            onMuteRequested: Audio.toggleOutputMute()
            onDeviceChosen: function(device) { Audio.selectSink(device); }
        }

        ToggleRow {
            width: parent.width
            label: "Mute microphone"
            checked: Audio.inputMuted
            enabled: Audio.ready
            onToggled: Audio.toggleInputMute()
        }

        InlineStatus {
            width: parent.width
            visible: !Audio.ready
            message: "PipeWire is unavailable"
        }

        ActionButton {
            label: "More audio controls"
            onActivated: {
                Control.selectPage("audio");
                SurfaceCoordinator.open("settings", root.screen);
            }
        }
    }
}
