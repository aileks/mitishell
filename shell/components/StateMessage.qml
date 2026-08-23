import QtQuick
import "../core"

Column {
    id: root

    property string title: ""
    property string description: ""
    property color accent: Theme.textMuted

    spacing: Theme.spaceXs

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        color: root.accent
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeTitle
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
    }

    Text {
        visible: root.description !== ""
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.description
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBodySmall
        wrapMode: Text.Wrap
    }
}
