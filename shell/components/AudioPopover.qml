import QtQuick
import "../core"

Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        Text {
            text: "Audio"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        AudioSlider {
            label: "Output"
            iconSource: Audio.outputMuted
                ? "../assets/icons/volume-x.svg"
                : "../assets/icons/volume-2.svg"
            currentValue: Audio.outputVolume
            onVolumeChanged: function(value) { Audio.setOutputVolume(value); }
            onMuteRequested: Audio.toggleOutputMute()
        }

        Text {
            text: "Output device"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Flickable {
            width: parent.width
            height: Math.min(outputDevices.implicitHeight, 78)
            contentWidth: width
            contentHeight: outputDevices.implicitHeight
            clip: true

            Column {
                id: outputDevices
                width: parent.width
                spacing: Theme.spaceXs

                Repeater {
                    model: Audio.sinks

                    delegate: AudioDeviceRow {
                        required property var modelData
                        width: outputDevices.width
                        node: modelData
                        selected: Audio.output === modelData
                        onChosen: Audio.selectSink(modelData)
                    }
                }
            }
        }

        AudioSlider {
            label: "Input"
            iconSource: Audio.inputMuted
                ? "../assets/icons/mic-off.svg"
                : "../assets/icons/mic.svg"
            currentValue: Audio.inputVolume
            onVolumeChanged: function(value) { Audio.setInputVolume(value); }
            onMuteRequested: Audio.toggleInputMute()
        }

        Text {
            text: "Input device"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Flickable {
            width: parent.width
            height: Math.min(inputDevices.implicitHeight, 78)
            contentWidth: width
            contentHeight: inputDevices.implicitHeight
            clip: true

            Column {
                id: inputDevices
                width: parent.width
                spacing: Theme.spaceXs

                Repeater {
                    model: Audio.sources

                    delegate: AudioDeviceRow {
                        required property var modelData
                        width: inputDevices.width
                        node: modelData
                        selected: Audio.input === modelData
                        onChosen: Audio.selectSource(modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: !Audio.ready
            text: "PipeWire is unavailable"
            color: Theme.red
            font.family: Theme.fontSans
            font.pixelSize: 10
        }
    }
}
