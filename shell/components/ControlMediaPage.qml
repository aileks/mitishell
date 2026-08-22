import QtQuick
import "../core"

Flickable {
    id: root

    contentWidth: width
    contentHeight: mediaPopover.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    MediaPopover {
        id: mediaPopover

        width: root.width
        height: Media.players.length > 1 ? 300 : 236
    }
}
