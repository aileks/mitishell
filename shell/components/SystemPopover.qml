import QtQuick
import "../core"
import "../lib/SystemModel.js" as SystemModel

Item {
    id: root
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: Theme.spaceMd

        Text {
            text: "System"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        Column {
            id: metrics
            width: parent.width
            spacing: Theme.spaceSm
            readonly property real cardWidth: (width - Theme.spaceSm) / 2

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                MetricCard {
                    width: metrics.cardWidth
                    label: "CPU"
                    value: SystemMetrics.cpuPercent + "%"
                }

                MetricCard {
                    width: metrics.cardWidth
                    label: "Memory"
                    value: SystemModel.bytes(SystemMetrics.memoryUsedBytes)
                        + " / " + SystemModel.bytes(SystemMetrics.memoryTotalBytes)
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                MetricCard {
                    width: metrics.cardWidth
                    visible: SystemMetrics.temperatureC !== null
                    label: "Temperature"
                    value: SystemMetrics.temperatureC !== null
                        ? SystemMetrics.temperatureC.toFixed(1) + " °C" : ""
                }

                MetricCard {
                    width: SystemMetrics.temperatureC !== null
                        ? metrics.cardWidth : metrics.width
                    label: "Uptime"
                    value: SystemModel.uptimeLabel(SystemMetrics.uptimeSeconds)
                }
            }

            MetricCard {
                width: parent.width
                label: "Load average"
                value: SystemMetrics.loadAverage.map(function(value) {
                    return value.toFixed(2);
                }).join("  ")
            }
        }
    }
}
