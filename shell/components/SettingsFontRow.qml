pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// The shell font picker: the shipped Adwaita default plus every installed
// Nerd Font family, each previewed in its own family. Choosing one saves
// immediately; the active entry carries the blue config accent.
Column {
    id: root

    required property string label
    readonly property string fieldKey: "font.family"
    required property string value

    readonly property string error: Settings.fieldErrors[fieldKey] || ""
    readonly property var choices: {
        const list = [{ value: "", label: "Default (Adwaita)" }];
        for (let index = 0; index < Fonts.families.length; index++) {
            const family = Fonts.families[index];
            list.push({ value: family, label: family });
        }
        return list;
    }

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    onVisibleChanged: {
        if (visible) Fonts.refresh();
    }

    Text {
        text: root.label
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        visible: Fonts.error !== ""
        text: Fonts.error
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }

    Flickable {
        width: parent.width
        height: Math.min(contentHeight, 6 * Theme.controlHeightSm + 5 * Theme.spaceXs)
        contentWidth: width
        contentHeight: fontColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: fontColumn

            width: parent.width
            spacing: Theme.spaceXs

            Repeater {
                model: root.choices

                delegate: SettingsPill {
                    required property var modelData

                    width: parent.width
                    label: modelData.label
                    fontFamily: modelData.value !== "" ? modelData.value : Theme.fontSans
                    checked: root.value === modelData.value
                    onChosen: Settings.setField(root.fieldKey, modelData.value)
                }
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
