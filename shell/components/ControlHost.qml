pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData

    readonly property bool open: SurfaceCoordinator.activeKey === "settings"
        && SurfaceCoordinator.originScreen === modelData

    screen: modelData
    visible: root.open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-settings"
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

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }
    }

    // A hotkey-summoned layer surface needs a short exclusive keyboard grab
    // before on-demand focus sticks; relax once the surface is mapped.
    property Timer focusPrime: Timer {
        interval: 75
        running: root.open
    }

    onOpenChanged: {
        if (open) {
            focusSelectedPage();
        }
    }

    function focusSelectedPage() {
        Qt.callLater(function() {
            root.focusRailButton(Control.pages.indexOf(Control.page));
        });
    }

    Connections {
        target: Control
        function onPageChanged() {
            if (root.open) {
                root.focusSelectedPage();
            }
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

    SurfaceFrame {
        id: card

        anchors.centerIn: parent
        width: Math.min(720, root.width - Theme.spaceXl * 2)
        height: Math.min(560, root.height - Theme.spaceXl * 2)
        floating: true
        padding: Theme.spaceLg
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Row {
            anchors.fill: parent
            spacing: Theme.spaceLg

            Column {
                id: rail

                width: 136
                spacing: Theme.spaceSm

                Repeater {
                    id: railRepeater

                    model: [
                        { key: "overview", label: "Overview", icon: "../assets/icons/home.svg", accent: Theme.orange },
                        { key: "audio", label: "Audio", icon: "../assets/icons/volume-2.svg", accent: Theme.orange },
                        { key: "display", label: "Display", icon: "../assets/icons/sun.svg", accent: Theme.blue },
                        { key: "network", label: "Network", icon: "../assets/icons/wifi.svg", accent: Theme.cyan },
                        { key: "bluetooth", label: "Bluetooth", icon: "../assets/icons/bluetooth.svg", accent: Theme.cyan },
                        { key: "system", label: "System", icon: "../assets/icons/settings.svg", accent: Theme.blue },
                    ]

                    delegate: Rectangle {
                        id: railButton

                        required property var modelData
                        required property int index

                        width: rail.width
                        height: Theme.controlHeightLg
                        radius: Theme.radiusPill
                        color: Control.page === modelData.key
                            ? Theme.alpha(modelData.accent, 0.22)
                            : (activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised)
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus ? Theme.blue
                            : (Control.page === modelData.key ? modelData.accent : Theme.borderStrong)
                        activeFocusOnTab: true
                        Accessible.name: modelData.label
                        Accessible.role: Accessible.Button
                        Accessible.onPressAction: selectPage()

                        function selectPage() {
                            forceActiveFocus(Qt.MouseFocusReason);
                            Control.selectPage(modelData.key);
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spaceMd
                            spacing: Theme.spaceSm

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.iconSm
                                height: Theme.iconSm
                                source: railButton.modelData.icon
                                sourceSize.width: 18
                                sourceSize.height: 18
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: railButton.modelData.label
                                color: Theme.textBright
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Control.page === railButton.modelData.key
                                    ? Font.DemiBold : Font.Normal
                            }
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: railButton.selectPage()
                        }

                        Keys.onReturnPressed: function(event) {
                            railButton.selectPage();
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: function(event) {
                            railButton.selectPage();
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
                    : Control.page === "display" ? displayPage
                    : Control.page === "network" ? networkPage
                    : Control.page === "bluetooth" ? bluetoothPage
                    : Control.page === "system" ? settingsPage
                    : homePage

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.duration(Motion.normal)
                        easing.type: Motion.easingStandard
                    }
                }

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
                    id: displayPage

                    ControlDisplayPage {
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
                        active: root.open
                    }
                }

                Component {
                    id: settingsPage

                    SettingsPage {
                        anchors.fill: parent
                    }
                }
            }
        }
    }
}
