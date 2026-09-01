pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

Item {
    id: root
    required property var screen
    property real nowMS: Date.now()
    implicitHeight: content.implicitHeight

    onVisibleChanged: if (visible) Reminders.refresh()

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.nowMS = Date.now()
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.spaceMd

        Text {
            text: "Reminders"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        InlineStatus {
            width: parent.width
            visible: !Reminders.available || Reminders.warning !== ""
            message: !Reminders.available ? Reminders.error : Reminders.warning
        }

        Text {
            visible: Reminders.available && Reminders.count === 0
            text: "No active reminders"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Repeater {
            model: Reminders.active.slice(0, 4)
            delegate: Item {
                id: reminderRow
                required property var modelData
                width: content.width
                height: Theme.controlHeight

                Column {
                    anchors.left: parent.left
                    anchors.right: cancel.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Theme.spaceSm
                    spacing: 1
                    Text {
                        width: parent.width
                        text: reminderRow.modelData.label
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }
                    Text {
                        text: ReminderModel.remainingLabel(reminderRow.modelData.fireAt, root.nowMS)
                        color: Theme.pink
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeMonoCaption
                    }
                }

                ActionButton {
                    id: cancel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 88
                    height: Theme.controlHeightSm
                    label: "Cancel"
                    destructive: true
                    accent: Theme.red
                    enabled: !Reminders.busy
                    onActivated: Reminders.cancel(reminderRow.modelData.id)
                }
            }
        }

        Text {
            visible: Reminders.count > 4
            text: "+" + (Reminders.count - 4) + " more"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeCaption
        }

        ActionButton {
            label: "New reminder"
            accent: Theme.pink
            onActivated: SurfaceCoordinator.open("reminders", root.screen)
        }
    }
}
