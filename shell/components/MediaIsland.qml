pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item {
    id: root

    implicitWidth: metadataViewport.implicitWidth + Theme.islandPadding
    implicitHeight: 30

    OverflowRow {
        id: metadataViewport
        objectName: "mediaMetadataViewport"

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spaceSm
        anchors.rightMargin: Theme.spaceSm
        animationsEnabled: Config.motion.enabled
        reducedMotion: Config.motion.reduced
        initialPauseDuration: Motion.duration(1200)
        endPauseDuration: Motion.duration(900)
        returnDuration: Motion.duration(Motion.normal)
        fallback: Text {
            objectName: "staticMetadata"
            anchors.verticalCenter: parent.verticalCenter
            width: metadataViewport.width
            text: Media.title + (Media.artist !== "" ? " • " + Media.artist : "")
            elide: Text.ElideRight
            color: Media.available ? Theme.textBright : Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
            font.weight: Font.DemiBold
        }

        spacing: Theme.spaceXs

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
