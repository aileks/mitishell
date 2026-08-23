pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"

// The settings window: a centered card over the focused output exposing
// the whole config schema. Every field saves itself through the CLI's
// validated `config set`, and the shell's file watcher applies it live.
PanelWindow {
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

    property Timer focusPrime: Timer {
        interval: 75
        running: root.open
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(function() {
                content.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

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
        width: 520
        height: 540
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

        Flickable {
            id: content

            anchors.fill: parent
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: settingsColumn

                width: content.width
                spacing: Theme.spaceMd

                Item {
                    width: parent.width
                    implicitHeight: heading.implicitHeight

                    Text {
                        id: heading

                        text: "Settings"
                        color: Theme.textBright
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeHeading
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.baseline: heading.baseline
                        text: Config.error !== "" ? "config invalid, defaults in use" : ""
                        visible: Config.error !== ""
                        color: Theme.red
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                SectionCard {
                    width: parent.width
                    title: "Bar"
                    accent: Theme.orange

                    Column {
                        id: barSection

                        width: parent.width
                        spacing: Theme.spaceMd

                        SettingsNumberRow {
                            width: parent.width
                            label: "Height"
                            fieldKey: "bar.height"
                            value: Config.bar.height
                            from: 24
                            to: 96
                        }

                        SettingsNumberRow {
                            width: parent.width
                            label: "Top margin"
                            fieldKey: "bar.marginTop"
                            value: Config.bar.marginTop
                            from: 0
                            to: 64
                        }

                        SettingsNumberRow {
                            width: parent.width
                            label: "Side margin"
                            fieldKey: "bar.marginHorizontal"
                            value: Config.bar.marginHorizontal
                            from: 0
                            to: 64
                        }

                        ToggleRow {
                            width: parent.width
                            accent: Theme.blue
                            label: "Window title"
                            description: "Show the focused window's title on the bar."
                            checked: Config.bar.showWindowTitle
                            onToggled: Settings.setField(
                                "bar.showWindowTitle", checked ? "false" : "true")
                        }

                        ToggleRow {
                            width: parent.width
                            accent: Theme.blue
                            label: "Media controls"
                            description: "Show the media island when something plays."
                            checked: Config.bar.showMedia
                            onToggled: Settings.setField(
                                "bar.showMedia", checked ? "false" : "true")
                        }

                        SettingsChoiceRow {
                            width: parent.width
                            label: "System metrics"
                            fieldKey: "bar.systemMetrics"
                            value: Config.bar.systemMetrics
                            choices: [
                                { value: "separate", label: "Separate" },
                                { value: "combined", label: "Combined" },
                                { value: "hidden", label: "Hidden" },
                            ]
                        }

                        SettingsOutputsRow {
                            width: parent.width
                        }
                    }
                }

                SectionCard {
                    width: parent.width
                    title: "Weather"
                    accent: Theme.cyan

                    Column {
                        id: weatherSection

                        width: parent.width
                        spacing: Theme.spaceMd

                        ToggleRow {
                            width: parent.width
                            accent: Theme.blue
                            label: "Enabled"
                            description: "Fetches forecasts from Open-Meteo using your rough location."
                            checked: Config.weather.enabled
                            onToggled: Settings.setField(
                                "weather.enabled", checked ? "false" : "true")
                        }

                        SettingsChoiceRow {
                            width: parent.width
                            label: "Units"
                            fieldKey: "weather.units"
                            value: Config.weather.units
                            choices: [
                                { value: "auto", label: "Auto" },
                                { value: "celsius", label: "Celsius" },
                                { value: "fahrenheit", label: "Fahrenheit" },
                            ]
                        }
                    }
                }

                SectionCard {
                    width: parent.width
                    title: "Motion"
                    accent: Theme.blue

                    Column {
                        id: motionSection

                        width: parent.width
                        spacing: Theme.spaceMd

                        ToggleRow {
                            width: parent.width
                            accent: Theme.blue
                            label: "Animations"
                            description: "Animate popovers, popups, and island changes."
                            checked: Config.motion.enabled
                            onToggled: Settings.setField(
                                "motion.enabled", checked ? "false" : "true")
                        }

                        ToggleRow {
                            width: parent.width
                            accent: Theme.blue
                            label: "Reduced motion"
                            description: "Shortens animations when they stay enabled."
                            checked: Config.motion.reduced
                            onToggled: Settings.setField(
                                "motion.reduced", checked ? "false" : "true")
                        }
                    }
                }
            }
        }
    }
}
