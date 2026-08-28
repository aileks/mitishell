import QtQuick
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

Row {
    id: root
    required property var screen
    spacing: Theme.spaceXs

    StatusButton {
        visible: Notifications.doNotDisturb
        iconSource: "../assets/icons/bell-off.svg"
        accessibleName: "Disable do not disturb"
        accent: Theme.orange
        onActivated: Notifications.toggleDoNotDisturb()
    }

    StatusButton {
        visible: NightLight.available && NightLight.enabled
        iconSource: "../assets/icons/moon.svg"
        accessibleName: "Disable night light"
        accent: Theme.yellow
        onActivated: NightLight.toggle()
    }

    StatusButton {
        visible: Audio.ready && Audio.inputMuted
        iconSource: "../assets/icons/mic-off.svg"
        accessibleName: "Unmute microphone"
        accent: Theme.red
        onActivated: {
            Audio.toggleInputMute();
            Osd.showMicMuted(Audio.inputMuted);
        }
    }

    Item {
        visible: ReminderModel.barVisible(Reminders.count)
        implicitWidth: reminderTrigger.implicitWidth
        implicitHeight: reminderTrigger.implicitHeight

        BarPopoverTrigger {
            id: reminderTrigger
            popoverKey: "reminderQuick"
            screen: root.screen
            Accessible.name: Reminders.count === 1
                ? "1 active reminder" : Reminders.count + " active reminders"

            ReminderIsland { open: reminderTrigger.active }
        }

        AnchoredPopover {
            anchorItem: reminderTrigger
            open: reminderTrigger.active
            contentWidth: 380
            contentHeight: Math.min(450, reminderPopover.implicitHeight + Theme.spaceLg * 2)
            ReminderPopover { id: reminderPopover; anchors.fill: parent; screen: root.screen }
        }
    }
}
