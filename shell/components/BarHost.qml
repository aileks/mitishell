import QtQuick
import Quickshell
import "../core"

PanelWindow {
    id: root

    required property var modelData
    readonly property real availableCenterWidth: Math.max(0, 2 * Math.min(
        width / 2 - leftIsland.width - Theme.spaceLg,
        width / 2 - rightIsland.width - Theme.spaceLg,
    ))

    screen: modelData
    visible: Config.outputEnabled(modelData.name)
    color: "transparent"
    implicitHeight: Config.bar.height
    exclusiveZone: visible ? implicitHeight + Config.bar.marginTop : 0

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Config.bar.marginTop
        left: Config.bar.marginHorizontal
        right: Config.bar.marginHorizontal
    }

    NotificationMediaCache {
        screen: root.modelData
    }

    Rectangle {
        id: leftIsland

        anchors.left: parent.left
        width: Math.min(leftContent.implicitWidth + Theme.spaceLg * 2, 560)
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Motion.easingStandard
            }
        }

        Row {
            id: leftContent

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceLg
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - Theme.spaceLg * 2)
            spacing: Theme.spaceMd

            WorkspaceStrip {
                id: workspaceStrip
                screen: root.modelData
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.overlay
                visible: Config.bar.showWindowTitle
            }

            WindowTitle {
                anchors.verticalCenter: parent.verticalCenter
                screen: root.modelData
                width: Math.min(implicitWidth, 280)
                visible: Config.bar.showWindowTitle
            }
        }
    }

    Rectangle {
        id: centerIsland

        anchors.horizontalCenter: parent.horizontalCenter
        width: visible
            ? Math.min(272, root.availableCenterWidth)
            : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.alpha(Theme.purple, 0.42)
        visible: Config.bar.showMedia && Media.meaningful
            && root.availableCenterWidth >= 72
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Motion.easingStandard
            }
        }

        BarPopoverTrigger {
            id: mediaTrigger

            anchors.centerIn: parent
            width: Math.max(0, parent.width - Theme.spaceLg * 2)
            clip: true
            popoverKey: "media"
            screen: root.modelData

            MediaIsland {
                width: mediaTrigger.width
            }
        }

        AnchoredPopover {
            anchorItem: mediaTrigger
            open: mediaTrigger.active && Config.bar.showMedia && Media.meaningful
            contentWidth: 360
            contentHeight: Media.players.length > 1 ? 300 : 236

            MediaPopover {
                anchors.fill: parent
            }
        }
    }

    Rectangle {
        id: rightIsland

        anchors.right: parent.right
        width: rightContent.implicitWidth > 0
            ? rightContent.implicitWidth + Theme.spaceLg * 2 : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle
        visible: width > 0

        Row {
            id: rightContent

            anchors.centerIn: parent
            spacing: Theme.spaceMd

            BarPopoverTrigger {
                id: systemTrigger

                visible: Config.bar.systemMetrics !== "hidden"
                popoverKey: "system"
                screen: root.modelData

                SystemMetricsIsland {
                    mode: Config.bar.systemMetrics
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                visible: Config.bar.systemMetrics !== "hidden"
                color: Theme.overlay
            }

            BarPopoverTrigger {
                id: audioTrigger

                popoverKey: "audio"
                screen: root.modelData

                AudioIsland {}
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.overlay
            }

            BarPopoverTrigger {
                id: clockTrigger

                popoverKey: "calendar"
                screen: root.modelData

                ClockIsland {}
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                visible: Tray.available
                color: Theme.overlay
            }

            TrayIsland {
                visible: Tray.available
                screen: root.modelData
            }

            ControlIsland {
                screen: root.modelData
            }

            BarPopoverTrigger {
                id: notificationsTrigger

                popoverKey: "notifications"
                screen: root.modelData

                NotificationIsland {
                    open: notificationsTrigger.active
                }
            }

            BarPopoverTrigger {
                id: remindersTrigger

                visible: Reminders.count > 0
                popoverKey: "reminders"
                screen: root.modelData
                Accessible.name: Reminders.count === 1
                    ? "1 active reminder"
                    : Reminders.count + " active reminders"
                Accessible.role: Accessible.Button

                ReminderIsland {
                    open: remindersTrigger.active
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                visible: Weather.visible
                color: Theme.overlay
            }

            BarPopoverTrigger {
                id: weatherTrigger

                visible: Weather.visible
                popoverKey: "weather"
                screen: root.modelData

                WeatherIsland {}
            }

            PowerIsland {
                screen: root.modelData
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                visible: Config.error !== ""
                color: Theme.red
            }
        }

        AnchoredPopover {
            anchorItem: systemTrigger
            open: systemTrigger.active && Config.bar.systemMetrics !== "hidden"
            contentWidth: 420
            contentHeight: SystemMetrics.temperatureC !== null ? 330 : 260

            SystemPopover {
                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: audioTrigger
            open: audioTrigger.active
            contentWidth: 420
            contentHeight: audioPopover.implicitHeight + Theme.spaceLg * 2

            AudioPopover {
                id: audioPopover

                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: clockTrigger
            open: clockTrigger.active
            contentWidth: calendarPopover.implicitWidth
            contentHeight: calendarPopover.implicitHeight + Theme.spaceLg * 2

            CalendarPopover {
                id: calendarPopover

                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: notificationsTrigger
            open: notificationsTrigger.active
            contentWidth: 380
            contentHeight: 460

            NotificationsPopover {
                anchors.fill: parent
            }
        }

        NotificationPopups {
            anchorItem: notificationsTrigger
        }

        AnchoredPopover {
            anchorItem: weatherTrigger
            open: weatherTrigger.active && Weather.visible
            contentWidth: 380
            contentHeight: 454

            WeatherPopover {
                anchors.fill: parent
            }
        }
    }
}
