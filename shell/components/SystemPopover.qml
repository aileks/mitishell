import QtQuick
import "../core"
import "../lib/SystemModel.js" as SystemModel

Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd

        Text {
            text: "System"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceSm
            rowSpacing: Theme.spaceSm

            MetricCard {
                label: "CPU"
                value: SystemMetrics.cpuPercent + "%"
            }

            MetricCard {
                label: "Memory"
                value: SystemModel.bytes(SystemMetrics.memoryUsedBytes)
                    + " / " + SystemModel.bytes(SystemMetrics.memoryTotalBytes)
            }

            MetricCard {
                label: "Load average"
                value: SystemMetrics.loadAverage.map(function(value) {
                    return value.toFixed(2);
                }).join("  ")
            }

            MetricCard {
                label: "Uptime"
                value: SystemModel.uptimeLabel(SystemMetrics.uptimeSeconds)
            }

            MetricCard {
                visible: SystemMetrics.temperatureC !== null
                label: "Temperature"
                value: SystemMetrics.temperatureC !== null
                    ? SystemMetrics.temperatureC.toFixed(1) + " °C" : ""
            }
        }

        Rectangle {
            id: missionCenterButton

            width: parent.width
            height: 38
            radius: Theme.radiusMedium
            color: activeFocus || buttonHover.hovered ? Theme.overlay : Theme.container
            border.width: activeFocus ? 2 : 0
            border.color: Theme.blue
            activeFocusOnTab: true
            Accessible.name: "Open Mission Center"
            Accessible.role: Accessible.Button
            Accessible.onPressAction: SystemMetrics.openMissionCenter()

            Text {
                anchors.centerIn: parent
                text: "Open Mission Center"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: buttonHover
            }

            TapHandler {
                onTapped: SystemMetrics.openMissionCenter()
            }

            Keys.onReturnPressed: function(event) {
                SystemMetrics.openMissionCenter();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                SystemMetrics.openMissionCenter();
                event.accepted = true;
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: SystemMetrics.launchError
            color: Theme.red
            wrapMode: Text.Wrap
            font.family: Theme.fontSans
            font.pixelSize: 10
        }
    }
}
