import QtQuick
import Quickshell
import "../core"

Item {
    id: root

    property string value: ""
    property int size: Theme.iconMd
    property color color: Theme.text
    readonly property bool localSource: value.indexOf("/") !== -1 || value.indexOf("file:") === 0
    readonly property string resolvedSource: localSource ? value : Quickshell.iconPath(value, true)

    implicitWidth: size
    implicitHeight: size

    Image {
        id: iconImage

        visible: source.toString() !== "" && status !== Image.Error
        anchors.fill: parent
        source: root.resolvedSource
        sourceSize.width: root.size
        sourceSize.height: root.size
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    Text {
        visible: !iconImage.visible
        anchors.centerIn: parent
        text: root.value
        color: root.color
        font.family: Theme.fontMono
        font.pixelSize: root.size
    }
}
