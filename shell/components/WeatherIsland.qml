import QtQuick
import "../core"
import "../lib/WeatherModel.js" as WeatherModel

Item {
    implicitWidth: content.implicitWidth
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 17
            height: 17
            weatherCode: Weather.snapshot !== null ? Weather.snapshot.current.weatherCode : -1
        }

        Text {
            text: WeatherModel.temperature(
                Weather.snapshot !== null ? Weather.snapshot.current.temperature : Number.NaN,
            )
            color: Weather.state === "stale" ? Theme.yellow : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
