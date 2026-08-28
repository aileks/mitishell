import QtQuick
import "../core"

Item {
    implicitWidth: 16 + Theme.spaceSm * 2
    implicitHeight: 24

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "../assets/icons/settings.svg"
        sourceSize.width: 32
        sourceSize.height: 32
    }
}
