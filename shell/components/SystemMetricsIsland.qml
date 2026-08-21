import QtQuick
import "../core"

Item {
    id: root

    required property string mode

    implicitWidth: content.implicitWidth
    implicitHeight: 24

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceSm

        Text {
            text: root.mode === "combined"
                ? "SYS " + SystemMetrics.cpuPercent + "/" + SystemMetrics.memoryPercent + "%"
                : "CPU " + SystemMetrics.cpuPercent + "%"
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

        Text {
            visible: root.mode === "separate"
            text: "RAM " + SystemMetrics.memoryPercent + "%"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
