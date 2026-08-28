import QtQuick
import "../core"

Item {
    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.description: "Right click to change time format"

    Row {
        id: content

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        spacing: Theme.spaceSm

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(Clock.now, Clock.timeFormat)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.clock.showDate
            text: Qt.formatDate(Clock.now, "MMM d")
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
            renderType: Text.NativeRendering
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: Clock.cycleFormat()
    }
}
