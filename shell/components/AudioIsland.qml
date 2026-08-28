import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Item {
    id: root

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Audio.outputMuted ? Icons.volumeOff : Icons.volumeHigh
            opacity: Audio.ready ? 1 : 0.5
        }

        Text {
            text: Audio.ready ? AudioModel.percent(Audio.outputVolume) + "%" : "--"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    WheelHandler {
        onWheel: function(event) {
            Audio.stepOutputVolume(event.angleDelta.y > 0 ? 0.02 : -0.02);
            Osd.showVolume();
            event.accepted = true;
        }
    }
}
