import QtQuick
import "../core"

Item {
    id: root

    property string accessibleName: "Brightness for all displays"

    implicitHeight: 58

    Text {
        id: brightnessLabel

        anchors.left: parent.left
        anchors.top: parent.top
        text: "Brightness"
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: brightnessLabel.verticalCenter
        text: Display.brightness + "%"
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeCaption
    }

    ShellSlider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        from: 1
        to: 100
        stepSize: 1
        value: Display.brightness
        Accessible.name: root.accessibleName
        onMoved: Display.setBrightness(value)
    }
}
