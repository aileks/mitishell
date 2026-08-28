import QtQuick
import "../core"

// The output and input device sections shared by the bar's audio popover
// and the Settings surface's Audio page.
Item {
    id: root

    implicitHeight: content.implicitHeight

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.spaceMd

        AudioSection {
            width: parent.width
            label: "Output"
            iconSource: Audio.outputMuted
                ? Icons.volumeOff
                : Icons.volumeHigh
            currentValue: Audio.outputVolume
            devices: Audio.sinks
            selectedDevice: Audio.output
            emptyMessage: "No output devices"
            onVolumeChanged: function(value) { Audio.setOutputVolume(value); }
            onMuteRequested: Audio.toggleOutputMute()
            onDeviceChosen: function(device) { Audio.selectSink(device); }
        }

        AudioSection {
            width: parent.width
            label: "Input"
            iconSource: Audio.inputMuted
                ? Icons.microphoneOff
                : Icons.microphone
            currentValue: Audio.inputVolume
            devices: Audio.sources
            selectedDevice: Audio.input
            emptyMessage: "No input devices"
            onVolumeChanged: function(value) { Audio.setInputVolume(value); }
            onMuteRequested: Audio.toggleInputMute()
            onDeviceChosen: function(device) { Audio.selectSource(device); }
        }

        InlineStatus {
            width: parent.width
            visible: !Audio.ready
            message: "PipeWire is unavailable"
        }
    }
}
