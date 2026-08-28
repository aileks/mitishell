import QtQuick
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

// Contextual timer state beside notifications. The surrounding trigger owns
// activation so this component only renders the active count.
FocusScope {
    id: root

    property bool open: false

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
            size: Theme.iconSm
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ReminderModel.barCountLabel(Reminders.count)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.open || root.activeFocus || hover.hovered
            ? Theme.alpha(Theme.pink, 0.14)
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.open ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.pink
        z: -1
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
}
