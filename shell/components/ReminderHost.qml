pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"
import "../lib/ReminderModel.js" as ReminderModel

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData

    readonly property bool open: SurfaceCoordinator.activeKey === "reminders"
        && SurfaceCoordinator.originScreen === modelData
    property real nowMS: Date.now()

    function schedule() {
        Reminders.schedule(minutesInput.text, messageInput.text);
    }

    screen: modelData
    visible: root.open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-reminders"
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

    property Timer remainingTimer: Timer {
        interval: 1000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: root.nowMS = Date.now()
    }

    onOpenChanged: {
        if (open) {
            Reminders.refresh();
            Qt.callLater(function() {
                minutesInput.forceActiveFocus(Qt.TabFocusReason);
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
        width: Math.min(560, root.width - Theme.spaceXl * 2)
        height: Math.min(
            root.height - Theme.spaceXl * 2,
            260 + Math.min(Reminders.count, 4) * 72
                + (Reminders.warning !== "" ? 72 : 0)
                + (!Reminders.available ? 52 : 0),
        )
        floating: true
        accent: Theme.pink
        padding: Theme.spaceLg
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98

        transform: Translate {
            y: root.open ? 0 : Theme.spaceMd

            Behavior on y {
                NumberAnimation {
                    duration: Motion.duration(Motion.quick)
                    easing.type: Motion.easingStandard
                }
            }
        }

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

        MouseArea { anchors.fill: parent }

        Column {
            id: content

            anchors.fill: parent
            spacing: Theme.spaceMd

            Item {
                width: parent.width
                height: Math.max(titleColumn.implicitHeight, activeBadge.implicitHeight)

                Column {
                    id: titleColumn

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs

                    Text {
                        text: "Reminders"
                        color: Theme.textBright
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeHeading
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Review active timers or start a new one."
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBodySmall
                    }
                }

                Rectangle {
                    id: activeBadge

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: badgeText.implicitWidth + Theme.spaceMd * 2
                    implicitHeight: Theme.controlHeightSm
                    radius: Theme.radiusPill
                    color: Theme.alpha(Theme.pink, 0.16)
                    border.width: 1
                    border.color: Theme.alpha(Theme.pink, 0.52)

                    Text {
                        id: badgeText

                        anchors.centerIn: parent
                        text: Reminders.count + " active"
                        color: Theme.pink
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }
            }

            StateMessage {
                visible: !Reminders.available
                width: parent.width
                title: "Reminders unavailable"
                description: Reminders.error
                    || "A user systemd session and runtime directory are required."
                accent: Theme.red
            }

            SectionCard {
                visible: Reminders.warning !== ""
                width: parent.width
                title: "Delivery pending"
                accent: Theme.yellow

                Text {
                    width: parent.width
                    text: Reminders.warning
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBodySmall
                    wrapMode: Text.Wrap
                }
            }

            SectionCard {
                width: parent.width
                title: "New reminder"
                accent: Theme.pink
                enabled: Reminders.available
                opacity: enabled ? 1 : 0.42

                Row {
                    id: createRow

                    width: parent.width
                    spacing: Theme.spaceSm

                    Rectangle {
                        id: minutesField

                        width: 96
                        height: Theme.controlHeightLg
                        radius: Theme.radiusMedium
                        color: Theme.layerInset
                        border.width: minutesInput.activeFocus ? 2 : 1
                        border.color: minutesInput.activeFocus
                            ? Theme.blue : Theme.borderStrong

                        TextInput {
                            id: minutesInput

                            anchors.fill: parent
                            anchors.margins: Theme.spaceMd
                            activeFocusOnTab: true
                            color: Theme.textBright
                            selectionColor: Theme.blue
                            selectedTextColor: Theme.background
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeBody
                            inputMethodHints: Qt.ImhDigitsOnly
                            maximumLength: 9
                            verticalAlignment: TextInput.AlignVCenter
                            Accessible.name: "Minutes"
                            Accessible.role: Accessible.EditableText
                            Keys.onReturnPressed: function(event) {
                                root.schedule();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceMd
                            visible: minutesInput.text === ""
                            text: "Minutes"
                            color: Theme.textMuted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeBodySmall
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        id: messageField

                        width: createRow.width - minutesField.width
                            - scheduleButton.width - createRow.spacing * 2
                        height: Theme.controlHeightLg
                        radius: Theme.radiusMedium
                        color: Theme.layerInset
                        border.width: messageInput.activeFocus ? 2 : 1
                        border.color: messageInput.activeFocus
                            ? Theme.blue : Theme.borderStrong

                        TextInput {
                            id: messageInput

                            anchors.fill: parent
                            anchors.margins: Theme.spaceMd
                            activeFocusOnTab: true
                            color: Theme.textBright
                            selectionColor: Theme.blue
                            selectedTextColor: Theme.background
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeBody
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            Accessible.name: "Reminder message"
                            Accessible.role: Accessible.EditableText
                            Keys.onReturnPressed: function(event) {
                                root.schedule();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceMd
                            visible: messageInput.text === ""
                            text: "Optional message"
                            color: Theme.textMuted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeBodySmall
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ActionButton {
                        id: scheduleButton

                        width: 104
                        height: Theme.controlHeightLg
                        label: Reminders.busy ? "Working" : "Schedule"
                        accent: Theme.pink
                        enabled: Reminders.available && !Reminders.busy
                        onActivated: root.schedule()
                    }
                }

                InlineStatus {
                    visible: Reminders.actionError !== ""
                    width: parent.width
                    message: Reminders.actionError
                    textSize: Theme.fontSizeBodySmall
                }
            }

            Item {
                visible: Reminders.available
                width: parent.width
                height: Math.max(0, content.height - y)

                Text {
                    id: activeHeading

                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Active reminders"
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                }

                ActionButton {
                    id: clearButton

                    visible: Reminders.count > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: activeHeading.verticalCenter
                    width: 96
                    height: Theme.controlHeightSm
                    label: "Clear all"
                    accent: Theme.red
                    destructive: true
                    enabled: !Reminders.busy
                    onActivated: Reminders.clear()
                }

                Flickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: activeHeading.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Theme.spaceSm
                    contentWidth: width
                    contentHeight: reminderList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: reminderList

                        width: parent.width
                        spacing: Theme.spaceSm

                        StateMessage {
                            visible: Reminders.count === 0
                            width: parent.width
                            title: "No active reminders"
                            description: "Create one above. It will appear here while its timer runs."
                            accent: Theme.textMuted
                        }

                        Repeater {
                            model: Reminders.active

                            delegate: Rectangle {
                                id: reminderRow

                                required property var modelData

                                width: reminderList.width
                                height: Math.max(72, reminderText.implicitHeight + Theme.spaceMd * 2)
                                radius: Theme.radiusMedium
                                color: Theme.layerRaised
                                border.width: 1
                                border.color: Theme.alpha(Theme.pink, 0.38)

                                Column {
                                    id: reminderText

                                    anchors.left: parent.left
                                    anchors.right: cancelButton.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spaceMd
                                    anchors.rightMargin: Theme.spaceMd
                                    spacing: Theme.spaceXs

                                    Text {
                                        width: parent.width
                                        text: reminderRow.modelData.label
                                        color: Theme.textBright
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontSizeBody
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: ReminderModel.remainingLabel(
                                            reminderRow.modelData.fireAt, root.nowMS)
                                            + " · "
                                            + Qt.formatTime(
                                                new Date(
                                                    Number(reminderRow.modelData.fireAt) * 1000),
                                                "h:mm AP")
                                        color: Theme.pink
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeCaption
                                        elide: Text.ElideRight
                                    }
                                }

                                ActionButton {
                                    id: cancelButton

                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spaceMd
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    height: Theme.controlHeightSm
                                    label: "Cancel"
                                    accent: Theme.pink
                                    enabled: !Reminders.busy
                                    onActivated: Reminders.cancel(reminderRow.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Reminders

        function onActionSerialChanged() {
            if (Reminders.lastAction === "schedule") {
                minutesInput.text = "";
                messageInput.text = "";
                minutesInput.forceActiveFocus(Qt.TabFocusReason);
            }
        }
    }
}
