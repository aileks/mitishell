import QtQuick
import "../core"
import "../lib/AudioModel.js" as AudioModel
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

        Text {
            text: "Home"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            implicitHeight: quickContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: quickContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
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
            }
        }

        Rectangle {
            width: parent.width
            visible: Media.meaningful
            implicitHeight: mediaContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Row {
                id: mediaContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
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
                    width: parent.width - 3 * 36 - 3 * Theme.spaceMd
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
            width: parent.width
            spacing: Theme.spaceMd

            Rectangle {
                width: Weather.visible
                    ? parent.width - 2 * 148 - 2 * parent.spacing
                    : 0
                height: 64
                visible: Weather.visible
                radius: Theme.radiusMedium
                color: Theme.container

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spaceSm

                    WeatherIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
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
                        color: Weather.state === "unavailable" ? Theme.red
                            : (Weather.state === "stale" ? Theme.yellow : Theme.text)
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }
            }

            MetricCard {
                label: "CPU"
                value: SystemMetrics.loaded
                    ? SystemMetrics.cpuPercent + "%" : "--"
            }

            MetricCard {
                label: "Memory"
                value: SystemMetrics.loaded
                    ? SystemMetrics.memoryPercent + "%" : "--"
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceXl

            IconButton {
                iconSource: "../assets/icons/settings.svg"
                accessibleName: "Open settings"
                onClicked: SurfaceCoordinator.toggle("settings", SurfaceCoordinator.originScreen)
            }

            IconButton {
                iconSource: "../assets/icons/power.svg"
                accessibleName: "Open power menu"
                onClicked: SurfaceCoordinator.toggle("power", SurfaceCoordinator.originScreen)
            }
        }
    }
}
