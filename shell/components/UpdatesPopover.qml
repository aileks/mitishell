import QtQuick
import "../core"

Item {
    implicitWidth: 360
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: Theme.spaceMd

        Text { text: "Available updates"; color: Theme.textBright; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeHeading; font.weight: Font.DemiBold }
        Text {
            text: Updates.result === null ? "Checking…" : Updates.result.system.count + " system  •  " + Updates.result.aur.count + " AUR"
            color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeBody
        }
        InlineStatus { visible: Updates.error !== ""; width: parent.width; message: Updates.error }

        Repeater {
            model: Updates.result === null ? [] : Updates.result.system.packages.slice(0, 8)
            delegate: Text { required property string modelData; text: modelData; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeCaption }
        }
        Text {
            visible: Updates.result !== null && Updates.result.system.count > 8
            text: Updates.result === null ? ""
                : "+" + (Updates.result.system.count - 8) + " more system updates"
            color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption
        }
        Text {
            visible: Updates.result !== null && Updates.result.helper === ""
            text: "AUR checks require paru or yay"
            color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption
        }
        InlineStatus {
            visible: Updates.result !== null && (Updates.result.aur.error || "") !== ""
            width: parent.width
            message: Updates.result === null ? "" : (Updates.result.aur.error || "")
            textSize: Theme.fontSizeCaption
        }
        Repeater {
            model: Updates.result === null ? [] : Updates.result.aur.packages.slice(0, 8)
            delegate: Text { required property string modelData; text: modelData; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeCaption }
        }
        Text {
            visible: Updates.result !== null && Updates.result.aur.count > 8
            text: Updates.result === null ? ""
                : "+" + (Updates.result.aur.count - 8) + " more AUR updates"
            color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption
        }

        Row {
            spacing: Theme.spaceSm
            ActionButton { label: Updates.state === "loading" ? "Checking…" : "Refresh"; enabled: Updates.state !== "loading"; onActivated: Updates.refresh() }
            ActionButton {
                label: "Update in terminal"
                enabled: Updates.result !== null && Updates.result.updateCommand && Updates.result.updateCommand.length > 0
                onActivated: Updates.launchUpdate()
            }
        }
        Text {
            visible: Updates.result !== null && (!Updates.result.updateCommand || Updates.result.updateCommand.length === 0)
            text: "No supported terminal was found"
            color: Theme.textMuted; font.family: Theme.fontSans; font.pixelSize: Theme.fontSizeCaption
        }
    }
}
