pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"

// The wlogout replacement: a centered action grid on the focused output.
// Choosing an action morphs the card into a confirmation of the same
// action; confirming runs it.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData

    readonly property bool open: SurfaceCoordinator.activeKey === "power"
        && SurfaceCoordinator.originScreen === modelData
    property string pendingAction: ""

    readonly property var actions: {
        const entries = [
            { key: "lock", label: "Lock", icon: "../assets/icons/lock.svg" },
            { key: "logout", label: "Log out", icon: "../assets/icons/log-out.svg" },
        ];
        if (Power.suspendAvailable) {
            entries.push({ key: "suspend", label: "Suspend", icon: "../assets/icons/moon.svg" });
        }
        if (Power.hibernateAvailable) {
            entries.push({ key: "hibernate", label: "Hibernate", icon: "../assets/icons/snowflake.svg" });
        }
        entries.push({ key: "reboot", label: "Reboot", icon: "../assets/icons/rotate-ccw.svg" });
        entries.push({ key: "shutdown", label: "Shut down", icon: "../assets/icons/power.svg" });
        return entries;
    }

    screen: modelData
    visible: root.open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-power"
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
            pendingAction = "";
            Qt.callLater(function() {
                grid.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: SurfaceCoordinator.close()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: {
            if (root.pendingAction !== "") {
                root.pendingAction = "";
            } else {
                SurfaceCoordinator.close();
            }
        }
    }

    SurfaceFrame {
        id: card

        anchors.centerIn: parent
        width: 440
        height: root.pendingAction !== "" ? confirmColumn.implicitHeight + Theme.spaceXl * 2
            : grid.implicitHeight + Theme.spaceXl * 2
        floating: true
        padding: 0
        accent: root.pendingAction !== "" ? Theme.red : Theme.orange
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

        Behavior on height {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        // The action grid morphs away once an action is pending.
        GridLayout {
            id: grid

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spaceXl
            columns: 3
            columnSpacing: Theme.spaceMd
            rowSpacing: Theme.spaceMd
            opacity: root.pendingAction === "" ? 1 : 0
            visible: opacity > 0
            activeFocusOnTab: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Motion.quick)
                    easing.type: Motion.easingStandard
                }
            }

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionTile

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    radius: Theme.radiusMedium
                    color: tilePress.pressed ? Theme.pressedFill
                        : (activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised)
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.blue : Theme.borderStrong
                    activeFocusOnTab: true
                    Accessible.name: actionTile.modelData.label
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: root.choose(actionTile.modelData.key)

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spaceSm

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20
                            height: 20
                            source: actionTile.modelData.icon
                            sourceSize.width: 20
                            sourceSize.height: 20
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionTile.modelData.label
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeCaption
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: tilePress
                        onTapped: root.choose(actionTile.modelData.key)
                    }

                    Keys.onReturnPressed: function(event) {
                        root.choose(actionTile.modelData.key);
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        root.choose(actionTile.modelData.key);
                        event.accepted = true;
                    }
                }
            }
        }

        Column {
            id: confirmColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spaceXl
            spacing: Theme.spaceLg
            opacity: root.pendingAction === "" ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Motion.quick)
                    easing.type: Motion.easingStandard
                }
            }

            readonly property var pending: {
                for (let index = 0; index < root.actions.length; index++) {
                    if (root.actions[index].key === root.pendingAction) {
                        return root.actions[index];
                    }
                }
                return null;
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                height: 28
                source: confirmColumn.pending !== null ? confirmColumn.pending.icon : ""
                sourceSize.width: 28
                sourceSize.height: 28
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: confirmColumn.pending !== null
                    ? "Confirm " + confirmColumn.pending.label.toLowerCase() + "?"
                    : ""
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeHeading
                font.weight: Font.DemiBold
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spaceMd

                Rectangle {
                    id: confirmButton

                    width: 120
                    height: 40
                    radius: Theme.radiusMedium
                    color: confirmPress.pressed ? Theme.pressedFill
                        : (activeFocus || confirmHover.hovered ? Theme.hoverFill : Theme.layerRaised)
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.blue : Theme.red
                    activeFocusOnTab: true
                    Accessible.name: "Confirm"
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: root.confirmPending()

                    Text {
                        anchors.centerIn: parent
                        text: "Confirm"
                        color: Theme.textBright
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: confirmHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: confirmPress
                        onTapped: root.confirmPending()
                    }

                    Keys.onReturnPressed: function(event) {
                        root.confirmPending();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        root.confirmPending();
                        event.accepted = true;
                    }
                }

                Rectangle {
                    id: cancelButton

                    width: 120
                    height: 40
                    radius: Theme.radiusMedium
                    color: cancelPress.pressed ? Theme.pressedFill
                        : (activeFocus || cancelHover.hovered ? Theme.hoverFill : Theme.layerRaised)
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.blue : Theme.borderStrong
                    activeFocusOnTab: true
                    Accessible.name: "Cancel"
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: root.pendingAction = ""

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                    }

                    HoverHandler {
                        id: cancelHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: cancelPress
                        onTapped: root.pendingAction = ""
                    }

                    Keys.onReturnPressed: function(event) {
                        root.pendingAction = "";
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        root.pendingAction = "";
                        event.accepted = true;
                    }
                }
            }
        }
    }

    function choose(action) {
        pendingAction = action;
    }

    function confirmPending() {
        if (pendingAction !== "") {
            Power.run(pendingAction);
            SurfaceCoordinator.close();
        }
    }
}
