import QtQuick
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

Row {
    id: root
    required property var screen
    spacing: Theme.spaceXs

    StatusButton {
        visible: NightLight.available && NightLight.enabled
        iconSource: Icons.moon
        accessibleName: "Disable night light"
        accent: Theme.yellow
        activeState: NightLight.enabled
        onActivated: NightLight.toggle()
    }

    StatusButton {
        visible: Audio.ready && Audio.inputMuted
        iconSource: Icons.microphoneOff
        accessibleName: "Unmute microphone"
        accent: Theme.red
        activeState: Audio.inputMuted
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
            accent: Theme.pink
            Accessible.name: Reminders.count === 1
                ? "1 active reminder" : Reminders.count + " active reminders"

            ReminderIsland {}
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
