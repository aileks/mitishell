import QtQuick
import "../core"

Column {
    id: root

    property string accessibleName: "Brightness for all displays"

    spacing: Theme.spaceXs

    Item {
        width: parent.width
        implicitHeight: brightnessLabel.implicitHeight

        Text {
            id: brightnessLabel

            anchors.left: parent.left
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
            font.pixelSize: Theme.fontSizeMonoCaption
        }
    }

    ShellSlider {
        width: parent.width
        height: Theme.controlHeightSm
        from: 1
        to: 100
        stepSize: 1
        value: Display.brightness
        Accessible.name: root.accessibleName
        onMoved: Display.setBrightness(value)
    }
}
