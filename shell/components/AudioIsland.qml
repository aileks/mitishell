import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Item {
    id: root

    implicitWidth: content.implicitWidth
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            source: Audio.outputMuted
                ? "../assets/icons/volume-x.svg"
                : "../assets/icons/volume-2.svg"
            sourceSize.width: 15
            sourceSize.height: 15
            opacity: Audio.ready ? 1 : 0.5
        }

        Text {
            text: Audio.ready ? AudioModel.percent(Audio.outputVolume) + "%" : "--"
            color: Audio.outputMuted ? Theme.red : Theme.text
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
