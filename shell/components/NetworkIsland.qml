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

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Icons.wifi
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Network.activeStation !== null ? Network.activeStation.signal + "%" : ""
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMonoCaption
        }
    }
}
