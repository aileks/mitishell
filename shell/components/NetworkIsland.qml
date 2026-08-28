import QtQuick
import "../core"

Item {
    id: root

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "../assets/icons/wifi.svg"
            sourceSize.width: 32
            sourceSize.height: 32
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Network.activeStation !== null ? Network.activeStation.signal + "%" : ""
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
