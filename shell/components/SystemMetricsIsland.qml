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

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: root.mode === "combined"
                ? "../assets/icons/computer.svg"
                : "../assets/icons/cpu.svg"
            sourceSize.width: 32
            sourceSize.height: 32
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

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.mode === "separate"
            width: visible ? 16 : 0
            height: 16

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: ""
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.iconMd
            }
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
