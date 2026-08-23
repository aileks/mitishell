import QtQuick
import "../core"

Item {
    id: root

    property string title: ""
    property string description: ""
    property color accent: Theme.orange

    implicitHeight: heading.implicitHeight + (description !== "" ? subheading.implicitHeight + Theme.spaceXs : 0)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        width: 4
        height: heading.implicitHeight
        radius: Theme.radiusPill
        color: root.accent
    }

    Text {
        id: heading

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.right: parent.right
        text: root.title
        color: Theme.textBright
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeHeading
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        id: subheading

        visible: root.description !== ""
        anchors.left: heading.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.topMargin: Theme.spaceXs
        text: root.description
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBodySmall
        wrapMode: Text.Wrap
    }
}
