pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root

    required property var modelData

    readonly property bool open: SurfaceCoordinator.activeKey === "control"
        && SurfaceCoordinator.originScreen === modelData

    screen: modelData
    visible: root.open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open
        ? (focusPrime.running ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A hotkey-summoned layer surface needs a short exclusive keyboard grab
    // before on-demand focus sticks; relax once the surface is mapped.
    property Timer focusPrime: Timer {
        interval: 75
        running: root.open
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(function() {
                root.focusRailButton(0);
            });
        }
    }

    function focusRailButton(index) {
        const buttons = rail.children.filter(function(child) {
            return child !== railRepeater;
        });
        if (index >= 0 && index < buttons.length) {
            buttons[index].forceActiveFocus(Qt.TabFocusReason);
        }
    }

    // The full-screen surface is modal: clicks outside the card dismiss it,
    // and the card swallows clicks aimed at its own empty space.
    MouseArea {
        anchors.fill: parent
        onClicked: SurfaceCoordinator.close()
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: SurfaceCoordinator.close()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: SurfaceCoordinator.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 620
        height: 520
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.overlay
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spaceLg
            spacing: Theme.spaceLg

            Column {
                id: rail

                width: 40
                spacing: Theme.spaceSm

                Repeater {
                    id: railRepeater

                    model: [
                        { key: "home", label: "Home", icon: "../assets/icons/home.svg" },
                        { key: "audio", label: "Audio", icon: "../assets/icons/volume-2.svg" },
                        { key: "media", label: "Media", icon: "../assets/icons/play.svg" },
                        { key: "display", label: "Display", icon: "../assets/icons/sun.svg" },
                        { key: "notifications", label: "Notifications", icon: "../assets/icons/bell.svg" },
                        { key: "network", label: "Network", icon: "../assets/icons/wifi.svg" },
                        { key: "bluetooth", label: "Bluetooth", icon: "../assets/icons/bluetooth.svg" },
                    ]

                    delegate: Rectangle {
                        id: railButton

                        required property var modelData
                        required property int index

                        width: 40
                        height: 40
                        radius: Theme.radiusPill
                        color: activeFocus || hover.hovered || Control.page === modelData.key
                            ? Theme.overlay
                            : "transparent"
                        border.width: activeFocus ? 2 : (Control.page === modelData.key ? 1 : 0)
                        border.color: activeFocus ? Theme.blue : Theme.orange
                        activeFocusOnTab: true
                        Accessible.name: modelData.label
                        Accessible.role: Accessible.Button
                        Accessible.onPressAction: Control.selectPage(modelData.key)

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: railButton.modelData.icon
                            sourceSize.width: 18
                            sourceSize.height: 18
                        }

                        HoverHandler {
                            id: hover
                        }

                        TapHandler {
                            onTapped: Control.selectPage(railButton.modelData.key)
                        }

                        Keys.onReturnPressed: function(event) {
                            Control.selectPage(railButton.modelData.key);
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: function(event) {
                            Control.selectPage(railButton.modelData.key);
                            event.accepted = true;
                        }
                        Keys.onDownPressed: function(event) {
                            root.focusRailButton(railButton.index + 1);
                            event.accepted = true;
                        }
                        Keys.onUpPressed: function(event) {
                            root.focusRailButton(railButton.index - 1);
                            event.accepted = true;
                        }
                    }
                }
            }

            Loader {
                id: pageLoader

                width: parent.width - rail.width - parent.spacing
                height: parent.height
                sourceComponent: Control.page === "audio" ? audioPage
                    : Control.page === "media" ? mediaPage
                    : Control.page === "display" ? displayPage
                    : Control.page === "notifications" ? notificationsPage
                    : Control.page === "network" ? networkPage
                    : Control.page === "bluetooth" ? bluetoothPage
                    : homePage

                Component {
                    id: homePage

                    ControlHomePage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: audioPage

                    ControlAudioPage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: mediaPage

                    ControlMediaPage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: displayPage

                    ControlDisplayPage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: notificationsPage

                    ControlNotificationsPage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: networkPage

                    ControlNetworkPage {
                        anchors.fill: parent
                    }
                }

                Component {
                    id: bluetoothPage

                    ControlBluetoothPage {
                        anchors.fill: parent
                    }
                }
            }
        }
    }
}
