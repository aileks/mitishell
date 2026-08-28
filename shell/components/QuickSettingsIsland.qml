import QtQuick
import "../core"

Item {
    implicitWidth: 16 + Theme.islandPadding
    implicitHeight: 24

    IconLabel {
        anchors.centerIn: parent
        value: Icons.settings
        size: Theme.iconMd
    }
}
