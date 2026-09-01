pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// A labeled numeric setting: mono value on the right, slider below,
// inline validation error underneath. Saves through a debounce so a
// drag writes once.
Column {
    id: root

    required property string label
    required property string fieldKey
    required property int value
    required property int from
    required property int to

    readonly property string error: Settings.fieldErrors[fieldKey] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Item {
        width: parent.width
        implicitHeight: valueLabel.implicitHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Text {
            id: valueLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: String(Math.round(slider.value))
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMonoBody
        }
    }

    ShellSlider {
        id: slider

        width: parent.width
        accent: Theme.blue
        from: root.from
        to: root.to
        stepSize: 1
        value: root.value
        Accessible.name: root.label
        onMoved: Settings.queueField(root.fieldKey, String(Math.round(value)))
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }
}
