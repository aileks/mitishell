pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/MediaModel.js" as MediaModel

Item {
    id: root

    readonly property var player: Media.activePlayer
    readonly property real trackLength: player !== null && player.lengthSupported
        ? player.length : 0
    readonly property real progress: trackLength > 0
        ? Math.max(0, Math.min(1, Media.displayPosition / trackLength)) : 0

    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd

        Row {
            width: parent.width
            height: 96
            spacing: Theme.spaceMd

            Rectangle {
                width: 96
                height: 96
                radius: Theme.radiusMedium
                color: Theme.container
                clip: true

                Image {
                    anchors.fill: parent
                    visible: root.player !== null && root.player.trackArtUrl !== ""
                    source: visible ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.player === null || root.player.trackArtUrl === ""
                    text: "music"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 96 - parent.spacing
                spacing: Theme.spaceXs

                Text {
                    width: parent.width
                    text: Media.title
                    elide: Text.ElideRight
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeHeading
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: Media.artist
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }

                Text {
                    width: parent.width
                    text: root.player !== null ? root.player.trackAlbum : ""
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Item {
            width: parent.width
            height: 26

            Rectangle {
                id: progressBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                height: 4
                radius: 2
                color: Theme.overlay

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.orange
                }
            }

            Text {
                id: positionLabel

                anchors.left: parent.left
                anchors.top: progressBar.bottom
                anchors.topMargin: Theme.spaceXs
                text: MediaModel.duration(Media.displayPosition)
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
            }

            Text {
                anchors.right: parent.right
                anchors.top: positionLabel.top
                text: MediaModel.duration(root.trackLength)
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceMd

            IconButton {
                iconSource: "../assets/icons/skip-back.svg"
                accessibleName: "Previous track"
                enabled: root.player !== null && root.player.canGoPrevious
                onClicked: Media.previous()
            }

            IconButton {
                iconSource: root.player !== null && root.player.isPlaying
                    ? "../assets/icons/pause.svg"
                    : "../assets/icons/play.svg"
                accessibleName: root.player !== null && root.player.isPlaying
                    ? "Pause" : "Play"
                enabled: root.player !== null && (root.player.canTogglePlaying
                    || root.player.canPlay || root.player.canPause)
                onClicked: Media.togglePlaying()
            }

            IconButton {
                iconSource: "../assets/icons/skip-forward.svg"
                accessibleName: "Next track"
                enabled: root.player !== null && root.player.canGoNext
                onClicked: Media.next()
            }
        }

        Text {
            visible: Media.players.length > 1
            text: "Players"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
            font.weight: Font.DemiBold
        }

        Flickable {
            visible: Media.players.length > 1
            width: parent.width
            height: 36
            contentWidth: playerRow.implicitWidth
            contentHeight: height
            clip: true

            Row {
                id: playerRow
                spacing: Theme.spaceSm

                Repeater {
                    model: Media.players

                    delegate: Rectangle {
                        id: playerChoice

                        required property var modelData
                        readonly property bool selected: root.player === modelData

                        width: playerLabel.implicitWidth + Theme.spaceLg * 2
                        height: 32
                        radius: Theme.radiusPill
                        color: selected ? Theme.orange : Theme.container
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.blue
                        activeFocusOnTab: true

                        Text {
                            id: playerLabel
                            anchors.centerIn: parent
                            text: playerChoice.modelData.identity
                                || playerChoice.modelData.desktopEntry
                                || "Unknown player"
                            color: playerChoice.selected ? Theme.background : Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeBody
                        }

                        TapHandler {
                            onTapped: Media.selectPlayer(playerChoice.modelData)
                        }

                        Keys.onReturnPressed: function(event) {
                            Media.selectPlayer(playerChoice.modelData);
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: function(event) {
                            Media.selectPlayer(playerChoice.modelData);
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
