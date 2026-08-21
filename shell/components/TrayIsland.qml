import QtQuick
import "../core"

Row {
    spacing: Theme.spaceXs
    height: 18

    Repeater {
        model: Tray.items.slice(0, 3)

        delegate: Item {
            required property var modelData

            width: 16
            height: 18

            Image {
                id: trayIcon

                anchors.centerIn: parent
                width: 14
                height: 14
                source: parent.modelData.icon
                sourceSize.width: 14
                sourceSize.height: 14
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                visible: trayIcon.source.toString() === "" || trayIcon.status === Image.Error
                text: "•"
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Tray.items.length > 3
        text: "+" + (Tray.items.length - 3)
        color: Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }
}
