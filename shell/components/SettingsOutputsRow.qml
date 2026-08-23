pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../lib/ConfigModel.js" as ConfigModel

// The bar outputs setting: an "All" pill plus one per connected screen.
// Toggling screens writes the connector list; choosing "All" writes the
// wildcard. Empty selections surface Go's validation error inline.
Column {
    id: root

    readonly property var screens: Quickshell.screens !== undefined
        ? Quickshell.screens : []
    readonly property string error: Settings.fieldErrors["bar.outputs"] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Text {
        text: "Outputs"
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        width: parent.width
        text: "Screens that get a bar. All follows every connected monitor."
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceSm

        SettingsPill {
            label: "All"
            checked: Config.bar.outputs.indexOf("*") !== -1
            onChosen: Settings.setField("bar.outputs", JSON.stringify(["*"]))
        }

        Repeater {
            model: root.screens

            delegate: SettingsPill {
                required property var modelData

                readonly property string connector: modelData.name

                label: modelData.name
                checked: ConfigModel.outputEnabled(Config.bar.outputs, connector)
                onChosen: {
                    const wildcard = Config.bar.outputs.indexOf("*") !== -1;
                    const current = wildcard ? [] : Config.bar.outputs.slice();
                    const index = current.indexOf(connector);
                    if (index === -1) {
                        current.push(connector);
                    } else {
                        current.splice(index, 1);
                    }
                    Settings.setField("bar.outputs", JSON.stringify(current));
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: root.error !== ""
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.red
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }
}
