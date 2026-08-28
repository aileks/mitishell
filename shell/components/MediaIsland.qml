import QtQuick
import "../core"

Item {
    id: root

    readonly property bool marqueeNeeded: Config.motion.enabled
        && !Config.motion.reduced
        && metadataStrip.implicitWidth > metadataViewport.width

    implicitWidth: metadataStrip.implicitWidth
    implicitHeight: 30

    function restartMarquee() {
        marquee.stop();
        metadataStrip.x = 0;
        if (marqueeNeeded) {
            Qt.callLater(function() {
                if (root.marqueeNeeded) {
                    marquee.start();
                }
            });
        }
    }

    onMarqueeNeededChanged: restartMarquee()

    Item {
        id: metadataViewport

        anchors.fill: parent
        clip: true

        onWidthChanged: root.restartMarquee()

        Row {
            id: metadataStrip

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            onImplicitWidthChanged: root.restartMarquee()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.title
                color: Media.available ? Theme.textBright : Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.artist !== ""
                text: "•"
                color: Theme.purple
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.artist !== ""
                text: Media.artist
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
            }
        }
    }

    SequentialAnimation {
        id: marquee

        loops: Animation.Infinite

        PauseAnimation {
            duration: Motion.duration(1200)
        }

        NumberAnimation {
            target: metadataStrip
            property: "x"
            to: metadataViewport.width - metadataStrip.implicitWidth
            duration: Motion.duration(Math.max(
                1200,
                (metadataStrip.implicitWidth - metadataViewport.width) * 32,
            ))
            easing.type: Easing.Linear
        }

        PauseAnimation {
            duration: Motion.duration(900)
        }

        NumberAnimation {
            target: metadataStrip
            property: "x"
            to: 0
            duration: Motion.duration(Motion.normal)
            easing.type: Motion.easingStandard
        }
    }
}
