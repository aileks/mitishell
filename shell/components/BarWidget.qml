pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item {
    id: root

    required property string widgetId
    required property var screen
    readonly property var widgets: ({
        workspaces: { component: workspacesComponent },
        windowTitle: { component: titleComponent },
        media: {
            component: mediaComponent,
            available: function() { return Media.meaningful; },
        },
        system: { component: systemComponent },
        audio: { component: audioComponent },
        keyboardLayout: {
            component: keyboardComponent,
            available: function() { return KeyboardLayout.available; },
        },
        updates: {
            component: updatesComponent,
            available: function() { return Updates.visible; },
        },
        clock: { component: clockComponent },
        tray: {
            component: trayComponent,
            available: function() { return Tray.available; },
        },
        network: {
            component: networkComponent,
            available: function() { return Network.available; },
        },
        bluetooth: {
            component: bluetoothComponent,
            available: function() { return Bluetooth.state === "ready"; },
        },
        quickSettings: { component: quickSettingsComponent },
        notifications: { component: notificationsComponent },
        weather: {
            component: weatherComponent,
            available: function() { return Weather.visible; },
        },
        status: { component: statusComponent },
        power: { component: powerComponent },
    })
    readonly property bool available: {
        const rule = widgets[widgetId];
        return rule !== undefined && rule.available !== undefined
            ? rule.available() : true;
    }
    readonly property var dragVisual: widgetLoader.item

    implicitWidth: available ? widgetLoader.implicitWidth : 0
    implicitHeight: 28
    visible: implicitWidth > 0

    Loader {
        id: widgetLoader
        anchors.centerIn: parent
        sourceComponent: {
            const rule = root.widgets[root.widgetId];
            return rule !== undefined ? rule.component : null;
        }
    }

    Component {
        id: workspacesComponent
        WorkspaceStrip { screen: root.screen }
    }

    Component {
        id: titleComponent
        Item {
            implicitWidth: title.text === "" ? 0 : Math.min(title.implicitWidth, 280)
            implicitHeight: 24
            WindowTitle { id: title; width: parent.width; height: parent.height; screen: root.screen }
        }
    }

    Component {
        id: mediaComponent
        Item {
            implicitWidth: Math.min(
                200,
                playbackButton.width + Theme.spaceSm + mediaContent.implicitWidth,
            )
            implicitHeight: 30

            Row {
                id: mediaRow
                anchors.fill: parent
                spacing: Theme.spaceSm

                FocusScope {
                    id: playbackButton

                    readonly property bool canToggle: Media.activePlayer !== null
                        && (Media.activePlayer.canTogglePlaying
                            || Media.activePlayer.canPlay || Media.activePlayer.canPause)

                    width: 16
                    height: parent.height
                    enabled: canToggle
                    activeFocusOnTab: enabled
                    Accessible.name: Media.activePlayer !== null
                        && Media.activePlayer.isPlaying ? "Pause" : "Play"
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: Media.togglePlaying()

                    IconLabel {
                        anchors.centerIn: parent
                        size: Theme.iconSm
                        value: Media.activePlayer !== null && Media.activePlayer.isPlaying
                            ? Icons.pause
                            : Icons.play
                        opacity: playbackButton.enabled ? 1 : 0.5
                    }

                    HoverHandler {
                        enabled: playbackButton.enabled
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: playbackButton.enabled
                        onTapped: Media.togglePlaying()
                    }
                    Keys.onReturnPressed: function(event) {
                        Media.togglePlaying();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        Media.togglePlaying();
                        event.accepted = true;
                    }
                }

                BarPopoverTrigger {
                    id: trigger
                    width: Math.max(0, parent.width - playbackButton.width - parent.spacing)
                    height: parent.height
                    popoverKey: "media"
                    screen: root.screen
                    clip: true
                    MediaIsland { id: mediaContent; width: trigger.width }
                }
            }
            AnchoredPopover {
                anchorItem: trigger
                open: trigger.active && Media.meaningful
                contentWidth: 360
                contentHeight: Media.players.length > 1 ? 300 : 236
                MediaPopover { anchors.fill: parent }
            }
        }
    }

    Component {
        id: systemComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger {
                id: trigger
                popoverKey: "system"
                screen: root.screen
                Accessible.name: "System monitor, CPU " + SystemMetrics.cpuPercent
                    + " percent, memory " + SystemMetrics.memoryPercent + " percent"
                SystemMetricsIsland { mode: Config.bar.systemMetrics }
            }
            AnchoredPopover {
                anchorItem: trigger
                open: trigger.active
                contentWidth: 420
                contentHeight: popover.implicitHeight + Theme.spaceLg * 2
                SystemPopover { id: popover; anchors.fill: parent }
            }
        }
    }

    Component {
        id: audioComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "audio"; screen: root.screen; AudioIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 420; contentHeight: Math.min(520, popover.implicitHeight + Theme.spaceLg * 2); AudioPopover { id: popover; anchors.fill: parent; screen: root.screen } }
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

    Component {
        id: networkComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "networkQuick"; screen: root.screen; NetworkIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 380; contentHeight: popover.implicitHeight + Theme.spaceLg * 2; NetworkPopover { id: popover; anchors.fill: parent; screen: root.screen } }
        }
    }

    Component {
        id: bluetoothComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "bluetoothQuick"; screen: root.screen; BluetoothIsland { open: trigger.active } }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 400; contentHeight: Math.min(480, popover.implicitHeight + Theme.spaceLg * 2); BluetoothPopover { id: popover; anchors.fill: parent; screen: root.screen } }
        }
    }

    Component {
        id: quickSettingsComponent
        Item {
            implicitWidth: trigger.implicitWidth
            implicitHeight: trigger.implicitHeight
            BarPopoverTrigger {
                id: trigger
                popoverKey: "quickSettings"
                screen: root.screen
                Accessible.name: "Open Quick Settings"
                QuickSettingsIsland {}
            }
            AnchoredPopover {
                anchorItem: trigger
                open: trigger.active
                contentWidth: 420
                contentHeight: Math.min(
                    560,
                    popover.implicitHeight + Theme.spaceLg * 2,
                )
                QuickSettingsPopover {
                    id: popover
                    anchors.fill: parent
                    screen: root.screen
                }
            }
        }
    }

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
        id: weatherComponent
        Item {
            implicitWidth: trigger.implicitWidth; implicitHeight: trigger.implicitHeight
            BarPopoverTrigger { id: trigger; popoverKey: "weather"; screen: root.screen; WeatherIsland {} }
            AnchoredPopover { anchorItem: trigger; open: trigger.active; contentWidth: 380; contentHeight: Math.min(680, popover.implicitHeight + Theme.spaceLg * 2); WeatherPopover { id: popover; anchors.fill: parent } }
        }
    }

    Component { id: statusComponent; StatusGroup { screen: root.screen } }
    Component { id: powerComponent; PowerIsland { screen: root.screen } }
}
