pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item {
    id: root

    required property string islandId
    required property var screen
    property bool separatorAfter: false
    readonly property bool available: islandId === "system" ? Config.bar.systemMetrics !== "hidden"
        : islandId === "keyboardLayout" ? KeyboardLayout.available
        : islandId === "updates" ? Updates.visible
        : islandId === "tray" ? Tray.available
        : islandId === "reminders" ? Reminders.count > 0
        : islandId === "weather" ? Weather.visible
        : true

    implicitWidth: available ? islandLoader.implicitWidth + (separatorAfter ? Theme.spaceMd + 1 : 0) : 0
    implicitHeight: 28
    visible: implicitWidth > 0

    Loader {
        id: islandLoader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.islandId === "system" ? systemComponent
            : root.islandId === "audio" ? audioComponent
            : root.islandId === "keyboardLayout" ? keyboardComponent
            : root.islandId === "updates" ? updatesComponent
            : root.islandId === "clock" ? clockComponent
            : root.islandId === "tray" ? trayComponent
            : root.islandId === "control" ? controlComponent
            : root.islandId === "notifications" ? notificationsComponent
            : root.islandId === "reminders" ? remindersComponent
            : root.islandId === "weather" ? weatherComponent
            : root.islandId === "power" ? powerComponent : null
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.separatorAfter
        width: 1
        height: 16
        color: Theme.overlay
    }

    Component {
        id: systemComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "system"; screen: root.screen; SystemMetricsIsland { mode: Config.bar.systemMetrics } }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 420; contentHeight: SystemMetrics.temperatureC !== null ? 330 : 260; SystemPopover { anchors.fill: parent } }
        }
    }
    Component {
        id: audioComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "audio"; screen: root.screen; AudioIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 420; contentHeight: popover.implicitHeight + Theme.spaceLg * 2; AudioPopover { id: popover; anchors.fill: parent } }
        }
    }
    Component { id: keyboardComponent; KeyboardLayoutIsland {} }
    Component {
        id: updatesComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "updates"; screen: root.screen; UpdatesIsland { open: trigger.active } }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 392; contentHeight: Math.min(520, popover.implicitHeight + Theme.spaceLg * 2); UpdatesPopover { id: popover; anchors.fill: parent } }
        }
    }
    Component {
        id: clockComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "calendar"; screen: root.screen; ClockIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: popover.implicitWidth + Theme.spaceLg * 2; contentHeight: popover.implicitHeight + Theme.spaceLg * 2; CalendarPopover { id: popover; anchors.fill: parent } }
        }
    }
    Component { id: trayComponent; TrayIsland { screen: root.screen } }
    Component { id: controlComponent; ControlIsland { screen: root.screen } }
    Component {
        id: notificationsComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "notifications"; screen: root.screen; NotificationIsland { open: trigger.active } }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 380; contentHeight: 460; NotificationsPopover { anchors.fill: parent } }
            NotificationPopups { anchorItem: trigger }
        }
    }
    Component {
        id: remindersComponent
        BarPopoverTrigger {
            id: reminderTrigger
            popoverKey: "reminders"; screen: root.screen
            Accessible.name: Reminders.count === 1 ? "1 active reminder" : Reminders.count + " active reminders"
            ReminderIsland { open: reminderTrigger.active }
        }
    }
    Component {
        id: weatherComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "weather"; screen: root.screen; WeatherIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 380; contentHeight: 454; WeatherPopover { anchors.fill: parent } }
        }
    }
    Component { id: powerComponent; PowerIsland { screen: root.screen } }
}
