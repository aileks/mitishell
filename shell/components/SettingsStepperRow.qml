pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// A bounded integer setting whose repeated steps coalesce through Settings
// before the shell reloads the saved config.
Column {
    id: root

    required property string label
    required property string fieldKey
    required property int value
    required property int from
    required property int to
    required property string valueFontFamily
    required property int valueFontSize

    property var settingsService: Settings
    readonly property string error: settingsService.fieldErrors[fieldKey] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Connections {
        target: root.settingsService

        function onFieldSaved(key, savedValue) {
            if (key === root.fieldKey) stepper.markSaved(Number(savedValue));
        }

        function onFieldSaveFailed(key, savedValue) {
            if (key === root.fieldKey) stepper.markFailed(Number(savedValue));
        }
    }

    IntegerStepper {
        id: stepper

        width: parent.width
        label: root.label
        value: root.value
        from: root.from
        to: root.to
        controlHeight: Theme.controlHeight
        spacing: Theme.spaceXs
        labelFontFamily: Theme.fontSans
        labelFontSize: Theme.fontSizeBody
        valueFontFamily: root.valueFontFamily
        valueFontSize: root.valueFontSize
        buttonFontFamily: Theme.fontMono
        buttonFontSize: Theme.barIconSize
        textColor: Theme.text
        valueColor: Theme.textBright
        pendingColor: Theme.yellow
        buttonColor: Theme.layerRaised
        hoverColor: Theme.hoverFill
        pressedColor: Theme.pressedFill
        borderColor: Theme.borderStrong
        focusColor: Theme.blue
        onValueQueued: function(value) {
            root.settingsService.queueField(root.fieldKey, String(value));
        }
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }
}
