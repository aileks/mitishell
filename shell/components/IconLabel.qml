import QtQuick
import "../core"

Item {
    id: root

    property string value: ""
    property int size: Theme.barIconSize

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        text: root.value
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: root.size
        renderType: Text.NativeRendering
    }
}
