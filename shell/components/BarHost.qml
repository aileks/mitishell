import QtQuick
import Quickshell
import "../core"

PanelWindow {
    id: root

    required property var modelData

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

    Rectangle {
        anchors.left: parent.left
        width: Math.min(leftContent.implicitWidth + Theme.spaceLg * 2, 560)
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: leftContent

            anchors.centerIn: parent
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
        width: Config.bar.showMedia && Media.meaningful
            ? Math.min(mediaTrigger.implicitWidth + Theme.spaceLg * 2, 360)
            : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container
        visible: Config.bar.showMedia && Media.meaningful

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Easing.OutCubic
            }
        }

        BarPopoverTrigger {
            id: mediaTrigger

            anchors.centerIn: parent
            popoverKey: "media"
            screen: root.modelData

            MediaIsland {}
        }

        AnchoredPopover {
            anchorItem: mediaTrigger
            open: mediaTrigger.active && Config.bar.showMedia && Media.meaningful
            contentWidth: 360
            contentHeight: 300

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
        color: Theme.container
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

            BarPopoverTrigger {
                id: trayTrigger

                visible: Tray.available
                popoverKey: "tray"
                screen: root.modelData

                TrayIsland {}
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
            contentWidth: 336
            contentHeight: SystemMetrics.temperatureC !== null ? 330 : 260

            SystemPopover {
                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: audioTrigger
            open: audioTrigger.active
            contentWidth: 376
            contentHeight: 404

            AudioPopover {
                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: clockTrigger
            open: clockTrigger.active
            contentWidth: 320
            contentHeight: 348

            CalendarPopover {
                anchors.fill: parent
            }
        }

        AnchoredPopover {
            anchorItem: trayTrigger
            open: trayTrigger.active && Tray.available
            contentWidth: 340
            contentHeight: 340

            TrayPopover {
                anchors.fill: parent
                opened: trayTrigger.active && Tray.available
            }
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
