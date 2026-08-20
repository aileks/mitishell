import QtQuick
import "../core"

Item {
    id: root

    implicitWidth: 280
    implicitHeight: 30

    Row {
        anchors.fill: parent
        spacing: Theme.spaceSm

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: Media.activePlayer !== null && Media.activePlayer.isPlaying
                ? "../assets/icons/pause.svg"
                : "../assets/icons/play.svg"
            sourceSize.width: 16
            sourceSize.height: 16
            opacity: Media.available ? 1 : 0.5
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 16 - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: Media.title
                elide: Text.ElideRight
                color: Media.available ? Theme.textBright : Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                elide: Text.ElideRight
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 9
            }
        }
    }
}
