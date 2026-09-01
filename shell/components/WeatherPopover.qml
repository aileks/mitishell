import QtQuick
import "../core"
import "../lib/WeatherModel.js" as WeatherModel

Flickable {
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
    readonly property string configuredLocation: Config.weather.location === ""
        ? "Automatic location" : Config.weather.location
    readonly property string resolvedLocation: Weather.snapshot !== null
        && Weather.snapshot.resolvedLocation !== ""
        ? Weather.snapshot.resolvedLocation : configuredLocation

    implicitWidth: 348
    implicitHeight: Math.min(640, content.implicitHeight)
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: content
        width: root.width
        spacing: Theme.spaceMd

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            Text {
                width: parent.width - refreshButton.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Weather"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeHeading
                font.weight: Font.DemiBold
            }

            IconButton {
                id: refreshButton

                iconSource: Icons.refresh
                accessibleName: "Refresh weather"
                enabled: Weather.state !== "locating"
                onClicked: Weather.refresh()
            }
        }
        Text { width: parent.width; visible: Weather.snapshot !== null; text: root.resolvedLocation; elide: Text.ElideRight; color: Theme.cyan; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBodySmall }
        Text { width: parent.width; visible: Weather.state === "locating"; text: Weather.snapshot === null ? "Fetching " + root.configuredLocation + "…" : "Refreshing " + root.configuredLocation + "…"; color: Theme.yellow; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBodySmall }
        InlineStatus {
            width: parent.width
            visible: Weather.state === "unavailable"
            message: "Weather unavailable for " + root.configuredLocation + ": "
                + (Weather.error !== "" ? Weather.error : "no data")
        }

        Row {
            width: parent.width
            height: 66
            spacing: Theme.spaceMd
            visible: Weather.snapshot !== null
            WeatherIcon { width: 54; height: 54; weatherCode: root.current.weatherCode }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 54 - parent.spacing
                spacing: 2
                Text { text: WeatherModel.temperature(root.current.temperature) + "  " + WeatherModel.condition(root.current.weatherCode).label; color: Theme.textBright; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeDisplay; font.weight: Font.DemiBold }
                Text { text: "Feels " + WeatherModel.temperature(root.current.apparent) + "  •  " + root.current.humidity + "% humidity"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBody }
                Text { text: "Wind " + Math.round(root.current.windSpeed) + " " + root.speedUnit; color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBody }
            }
        }

        Text { visible: Weather.snapshot !== null; text: "Hourly"; color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption; font.weight: Font.DemiBold }
        Flickable {
            visible: Weather.snapshot !== null
            width: parent.width
            height: 72
            contentWidth: hourlyRow.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: hourlyRow
                spacing: Theme.spaceSm
                Repeater {
                    model: Weather.snapshot !== null ? Weather.snapshot.hourly : []
                    delegate: Rectangle {
                        id: hourlyCard
                        required property var modelData
                        width: 54
                        height: 70
                        radius: Theme.radiusMedium
                        color: Theme.container
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: WeatherModel.hour(hourlyCard.modelData.time); color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeMonoCaption }
                            WeatherIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; weatherCode: hourlyCard.modelData.weatherCode }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: WeatherModel.temperature(hourlyCard.modelData.temperature); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeMonoCaption }
                        }
                    }
                }
            }
        }

        Text { visible: Weather.snapshot !== null; text: "Daily"; color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption; font.weight: Font.DemiBold }
        Column {
            visible: Weather.snapshot !== null
            width: parent.width
            spacing: Theme.spaceXs
            Repeater {
                model: Weather.snapshot !== null ? Weather.snapshot.daily : []
                delegate: Row {
                    id: dailyRow
                    required property var modelData
                    width: parent.width
                    height: 30
                    spacing: Theme.spaceSm
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 70; text: Qt.formatDate(new Date(dailyRow.modelData.date + "T12:00"), "ddd"); color: Theme.text; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBody }
                    WeatherIcon { anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; weatherCode: dailyRow.modelData.weatherCode }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 98; horizontalAlignment: Text.AlignRight; text: WeatherModel.temperature(dailyRow.modelData.maximum) + "  " + WeatherModel.temperature(dailyRow.modelData.minimum); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeMonoCaption }
                }
            }
        }

        Text { width: parent.width; visible: Weather.state === "stale"; text: "Last updated " + Weather.ageMinutes + " minutes ago"; color: Theme.yellow; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption }
        WeatherLocationEditor { width: parent.width }
    }
}
