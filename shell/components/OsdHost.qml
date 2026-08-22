import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../lib/OsdModel.js" as OsdModel

PanelWindow {
    id: root

    required property var modelData

    // Visual-only overlay: no keyboard focus, no exclusive zone, and an
    // empty input region so clicks reach the desktop below.

    screen: modelData
    visible: root.focused || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "mitishell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    readonly property bool focused: Osd.open && Osd.screenName === modelData.name

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        width: content.implicitWidth + Theme.spaceLg * 2
        height: 44
        radius: Theme.radiusPill
        color: Theme.container
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: Theme.spaceMd

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "../assets/icons/" + OsdModel.iconFor(
                    Osd.kind, Math.round(Osd.progress * 100), Osd.muted) + ".svg"
                sourceSize.width: 18
                sourceSize.height: 18
            }

            Rectangle {
                visible: Osd.barVisible
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                height: 6
                radius: 3
                color: Theme.overlay

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: Math.round(parent.width * Osd.progress)
                    radius: 3
                    color: Theme.blue

                    Behavior on width {
                        NumberAnimation {
                            duration: Motion.duration(Motion.quick)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                visible: Osd.barVisible
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: 40
                text: Osd.label
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
            }

            Text {
                visible: !Osd.barVisible
                anchors.verticalCenter: parent.verticalCenter
                text: Osd.message
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }
}
