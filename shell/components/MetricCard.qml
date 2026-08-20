import QtQuick
import "../core"

Rectangle {
    id: root

    required property string label
    required property string value

    implicitWidth: 148
    implicitHeight: 64
    radius: Theme.radiusMedium
    color: Theme.container

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceXs

        Text {
            text: root.label
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: root.value
            elide: Text.ElideRight
            color: Theme.textBright
            font.family: Theme.fontMono
            font.pixelSize: 14
        }
    }
}
