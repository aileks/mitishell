import QtQuick
import "../core"

Row {
    spacing: Theme.spaceSm

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(Clock.now, Clock.timeFormat)
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.clock.showDate
        text: Qt.formatDate(Clock.now, "MMM d")
        color: Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }
}
