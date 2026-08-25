import QtQuick
import "../core"

Column {
    id: root

    property string title: ""
    property string description: ""
    property color accent: Theme.orange

    spacing: Theme.spaceXs

    Text {
        id: heading

        width: parent.width
        text: root.title
        color: Theme.textBright
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeHeading
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Rectangle {
        width: Theme.spaceXl
        height: 3
        radius: Theme.radiusPill
        color: root.accent
    }

    Text {
        id: subheading

        visible: root.description !== ""
        width: parent.width
        text: root.description
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBodySmall
        wrapMode: Text.Wrap
    }
}
