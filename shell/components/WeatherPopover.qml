import QtQuick
import "../core"
import "../lib/WeatherModel.js" as WeatherModel

Item {
    id: root

    readonly property var current: Weather.snapshot !== null ? Weather.snapshot.current : ({
        "temperature": Number.NaN,
        "apparent": Number.NaN,
        "humidity": 0,
        "weatherCode": -1,
        "windSpeed": 0
    })
    readonly property string speedUnit: Weather.snapshot !== null
        && Weather.snapshot.units === "fahrenheit" ? "mph" : "km/h"

    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd

        Row {
            width: parent.width
            height: 66
            spacing: Theme.spaceMd

            WeatherIcon {
                width: 54
                height: 54
                weatherCode: root.current.weatherCode
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 54 - parent.spacing
                spacing: 2

                Text {
                    text: WeatherModel.temperature(root.current.temperature)
                        + "  " + WeatherModel.condition(root.current.weatherCode).label
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Feels " + WeatherModel.temperature(root.current.apparent)
                        + "  •  " + root.current.humidity + "% humidity"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                }

                Text {
                    text: "Wind " + Math.round(root.current.windSpeed) + " " + root.speedUnit
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                }
            }
        }

        Text {
            text: "Next 12 hours"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Flickable {
            width: parent.width
            height: 72
            contentWidth: hourlyRow.implicitWidth
            contentHeight: height
            clip: true

            Row {
                id: hourlyRow
                spacing: Theme.spaceSm

                Repeater {
                    model: Weather.snapshot !== null ? Weather.snapshot.hourly : []

                    delegate: Rectangle {
                        required property var modelData
                        width: 54
                        height: 70
                        radius: Theme.radiusMedium
                        color: Theme.container

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: WeatherModel.hour(modelData.time)
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                            }
                            WeatherIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 20
                                height: 20
                                weatherCode: modelData.weatherCode
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: WeatherModel.temperature(modelData.temperature)
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "Five days"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Column {
            width: parent.width
            spacing: Theme.spaceXs

            Repeater {
                model: Weather.snapshot !== null ? Weather.snapshot.daily : []

                delegate: Row {
                    required property var modelData
                    width: parent.width
                    height: 30
                    spacing: Theme.spaceSm

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                        text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd")
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 10
                    }
                    WeatherIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        weatherCode: modelData.weatherCode
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 98
                        horizontalAlignment: Text.AlignRight
                        text: WeatherModel.temperature(modelData.maximum)
                            + "  " + WeatherModel.temperature(modelData.minimum)
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: Weather.state === "stale"
            text: "Last updated " + Weather.ageMinutes + " minutes ago"
            color: Theme.yellow
            font.family: Theme.fontSans
            font.pixelSize: 9
        }

        Text {
            text: "Weather data by Open-Meteo"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 9
        }
    }
}
