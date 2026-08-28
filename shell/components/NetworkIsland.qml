import QtQuick
import "../core"

Item {
    id: root

    readonly property var activeStation: {
        if (Network.wifi === null) return null;
        const stations = Network.wifi.stations || [];
        for (let index = 0; index < stations.length; index += 1) {
            if (stations[index].inUse) return stations[index];
        }
        return null;
    }

    implicitWidth: content.implicitWidth + Theme.spaceSm * 2
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
            text: root.activeStation !== null ? root.activeStation.signal + "%" : ""
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
