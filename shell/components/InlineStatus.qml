import QtQuick
import "../core"

// Readable inline status copy with a semantic, non-text indicator.
Item {
    id: root

    property string message: ""
    property color accent: Theme.red
    property int textSize: Theme.fontSizeBody

    implicitHeight: messageText.implicitHeight

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.spaceXs
        radius: Theme.radiusPill
        color: root.accent
    }

    Text {
        id: messageText

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.right: parent.right
        text: root.message
        color: Theme.text
        wrapMode: Text.Wrap
        font.family: Theme.fontSans
        font.pixelSize: root.textSize
    }
}
