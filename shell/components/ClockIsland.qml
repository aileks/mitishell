import QtQuick
import "../core"

Item {
    implicitWidth: clockLabel.implicitWidth
    implicitHeight: 24

    Text {
        id: clockLabel

        anchors.centerIn: parent
        text: Qt.formatTime(Clock.now, Locale.ShortFormat)
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: 10
    }
}
