import QtQuick
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

// Contextual timer state beside notifications. The surrounding trigger owns
// activation so this component only renders the active count.
FocusScope {
    id: root

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.name: ReminderModel.countLabel(Reminders.count)
    Accessible.role: Accessible.Button

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Icons.alarmClock
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ReminderModel.barCountLabel(Reminders.count)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMonoCaption
        }
    }
}
