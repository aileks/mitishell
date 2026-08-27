import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel

Item {
    id: root

    implicitWidth: content.implicitWidth + Theme.spaceSm * 2
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: Audio.outputMuted
                ? "../assets/icons/volume-x.svg"
                : "../assets/icons/volume-2.svg"
            // Raster at twice the drawn size; the filtered downscale keeps
            // the thin arcs crisp at bar scale.
            sourceSize.width: 32
            sourceSize.height: 32
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
