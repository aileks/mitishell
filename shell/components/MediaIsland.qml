pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item {
    id: root

    implicitWidth: metadata.contentImplicitWidth + Theme.islandPadding
    implicitHeight: 30

    MediaMetadata {
        id: metadata

        anchors.fill: parent
        title: Media.title
        artist: Media.artist
        titleColor: Media.available ? Theme.textBright : Theme.textMuted
        artistColor: Theme.textMuted
        accentColor: Theme.purple
        fontFamily: Theme.fontSans
        titleFontSize: Theme.fontSizeBody
        artistFontSize: Theme.fontSizeCaption
        horizontalPadding: Theme.spaceSm
        itemSpacing: Theme.spaceXs
        animationsEnabled: Config.motion.enabled
        reducedMotion: Config.motion.reduced
        initialPauseDuration: Motion.duration(1200)
        endPauseDuration: Motion.duration(900)
        returnDuration: Motion.duration(Motion.normal)
    }
}
