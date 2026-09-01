import QtQuick
import "../core"

Rectangle {
    id: root

    required property string label
    required property string value
    property color accent: Theme.orange

    implicitWidth: 148
    implicitHeight: 64
    radius: Theme.radiusMedium
    color: Theme.layerRaised
    border.width: 1
    border.color: Theme.alpha(root.accent, 0.38)

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceXs

        Text {
            text: root.label
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: root.value
            elide: Text.ElideRight
            color: Theme.textBright
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMonoBody
        }
    }
}
