import QtQuick
import "../lib/WeatherModel.js" as WeatherModel

Image {
    id: root

    required property int weatherCode
    readonly property var condition: WeatherModel.condition(weatherCode)

    source: "../assets/weather/" + condition.key + ".svg"
    sourceSize.width: width
    sourceSize.height: height
}
