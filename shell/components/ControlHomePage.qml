import QtQuick
import "../core"
import "../lib/WeatherModel.js" as WeatherModel

Flickable {
    id: root

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
            title: "Home"
            accent: Theme.orange
        }

        SectionCard {
            width: parent.width
            title: "Quick controls"
            accent: Theme.orange

            Column {
                id: quickContent

                width: parent.width
                spacing: Theme.spaceSm

                AudioSlider {
                    width: parent.width
                    label: "Volume"
                    iconSource: Audio.outputMuted
                        ? "../assets/icons/volume-x.svg"
                        : "../assets/icons/volume-2.svg"
                    currentValue: Audio.outputVolume
                    onVolumeChanged: function(value) { Audio.setOutputVolume(value); }
                    onMuteRequested: Audio.toggleOutputMute()
                }

                Item {
                    width: parent.width
                    implicitHeight: 58
                    visible: Display.available

                    Text {
                        id: brightnessLabel

                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Brightness"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: brightnessLabel.verticalCenter
                        text: Display.brightness + "%"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }

                    ShellSlider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        from: 1
                        to: 100
                        stepSize: 1
                        value: Display.brightness
                        Accessible.name: "Brightness"
                        onMoved: Display.setBrightness(value)
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Do not disturb"
                    checked: Notifications.doNotDisturb
                    onToggled: Notifications.toggleDoNotDisturb()
                }

                ToggleRow {
                    width: parent.width
                    visible: NightLight.available
                    label: "Night light"
                    description: NightLight.description
                    checked: NightLight.enabled
                    enabled: !NightLight.busy
                    onToggled: NightLight.toggle()
                }
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
