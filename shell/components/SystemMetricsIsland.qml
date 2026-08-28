import QtQuick
import "../core"

Item {
    id: root

    required property string mode

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceSm

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: root.mode === "combined"
                ? Icons.computer
                : Icons.cpu
        }

        Text {
            text: root.mode === "combined"
                ? SystemMetrics.cpuPercent + "/" + SystemMetrics.memoryPercent + "%"
                : SystemMetrics.cpuPercent + "%"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            visible: root.mode === "separate"
            color: Theme.overlay
        }

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.mode === "separate"
            size: visible ? Theme.barIconSize : 0
            value: Icons.memory
        }

        Text {
            visible: root.mode === "separate"
            text: SystemMetrics.memoryPercent + "%"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
