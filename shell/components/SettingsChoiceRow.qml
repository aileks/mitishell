pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// A labeled multi-choice setting rendered as a row of pills. Choosing one
// saves immediately; the active pill carries the orange accent.
Column {
    id: root

    required property string label
    required property string fieldKey
    required property string value
    required property var choices

    readonly property string error: Settings.fieldErrors[fieldKey] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Text {
        text: root.label
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Row {
        spacing: Theme.spaceSm

        Repeater {
            model: root.choices

            delegate: SettingsPill {
                required property var modelData

                label: modelData.label
                checked: root.value === modelData.value
                onChosen: Settings.setField(root.fieldKey, modelData.value)
            }
        }
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }
}
