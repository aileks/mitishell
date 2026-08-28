import QtQuick
import "../core"
import "../lib/WeatherModel.js" as WeatherModel

Flickable {
    id: root

    acceptedButtons: Qt.NoButton
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: content

        width: root.width
        spacing: Theme.spaceMd

        SurfaceHeader {
            width: parent.width
            title: "Overview"
            accent: Theme.orange
        }

        SectionCard {
            width: parent.width
            title: "Quick controls"
            accent: Theme.orange

            QuickControls {
                id: quickContent

                width: parent.width
            }
        }

        SectionCard {
            width: parent.width
            visible: Media.meaningful
            title: "Now playing"
            accent: Theme.purple

            Row {
                width: parent.width
                spacing: Theme.spaceMd

                IconButton {
                    iconSource: "../assets/icons/skip-back.svg"
                    accessibleName: "Previous track"
                    enabled: Media.activePlayer !== null && Media.activePlayer.canGoPrevious
                    onClicked: Media.previous()
                }

                IconButton {
                    iconSource: Media.activePlayer !== null && Media.activePlayer.isPlaying
                        ? "../assets/icons/pause.svg"
                        : "../assets/icons/play.svg"
                    accessibleName: Media.activePlayer !== null && Media.activePlayer.isPlaying
                        ? "Pause" : "Play"
                    enabled: Media.activePlayer !== null
                    onClicked: Media.togglePlaying()
                }

                IconButton {
                    iconSource: "../assets/icons/skip-forward.svg"
                    accessibleName: "Next track"
                    enabled: Media.activePlayer !== null && Media.activePlayer.canGoNext
                    onClicked: Media.next()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 3 * Theme.controlHeight - 3 * Theme.spaceMd
                    spacing: Theme.spaceXs

                    Text {
                        width: parent.width
                        text: Media.title
                        elide: Text.ElideRight
                        color: Theme.textBright
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: Media.artist
                        elide: Text.ElideRight
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }
            }
        }

        Row {
            id: metricsRow

            readonly property int cardCount: Weather.visible ? 3 : 2
            readonly property real cardWidth: (width - spacing * (cardCount - 1)) / cardCount

            width: parent.width
            spacing: Theme.spaceMd

            Rectangle {
                width: metricsRow.cardWidth
                height: 64
                visible: Weather.visible
                radius: Theme.radiusMedium
                color: Theme.layerRaised
                border.width: 1
                border.color: Weather.state === "unavailable" ? Theme.red
                    : (Weather.state === "stale" || Weather.state === "locating"
                        ? Theme.yellow : Theme.alpha(Theme.cyan, 0.68))

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceMd
                    spacing: Theme.spaceXs

                    Text {
                        text: "Weather"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Row {
                        spacing: Theme.spaceSm

                        WeatherIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSm
                            height: Theme.iconSm
                            weatherCode: Weather.snapshot !== null
                                ? Weather.snapshot.current.weatherCode : -1
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: WeatherModel.temperature(
                                Weather.snapshot !== null
                                    ? Weather.snapshot.current.temperature
                                    : Number.NaN,
                            )
                            color: Weather.state === "stale" ? Theme.yellow : Theme.textBright
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeBody
                        }
                    }
                }
            }

            MetricCard {
                width: metricsRow.cardWidth
                label: "CPU"
                value: SystemMetrics.loaded
                    ? SystemMetrics.cpuPercent + "%" : "--"
            }

            MetricCard {
                width: metricsRow.cardWidth
                label: "Memory"
                value: SystemMetrics.loaded
                    ? SystemMetrics.memoryPercent + "%" : "--"
            }
        }

    }
}
