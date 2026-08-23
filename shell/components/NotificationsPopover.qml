pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// The bell popover: recent history with actions, quick dismiss, and the
// do-not-disturb switch, anchored under the island.
Flickable {
    id: root

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: {
        if (visible) {
            Notifications.markSeen();
        }
    }

    Column {
        id: content

        width: root.width
        spacing: Theme.spaceMd

        Row {
            width: parent.width
            spacing: Theme.spaceMd

            Text {
                id: heading

                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeHeading
                font.weight: Font.DemiBold
            }

            Item { width: parent.width - clearAll.implicitWidth - heading.implicitWidth - Theme.spaceMd; height: 1 }

            Rectangle {
                id: clearAll

                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.history.length > 0
                width: clearAllLabel.implicitWidth + Theme.spaceLg * 2
                height: 28
                radius: Theme.radiusPill
                color: activeFocus || clearHover.hovered ? Theme.overlay : Theme.container
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? Theme.blue : Theme.overlay
                activeFocusOnTab: true
                Accessible.name: "Clear notification history"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: Notifications.clearHistory()

                Text {
                    id: clearAllLabel

                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeCaption
                }

                HoverHandler {
                    id: clearHover
                }

                TapHandler {
                    onTapped: Notifications.clearHistory()
                }

                Keys.onReturnPressed: function(event) {
                    Notifications.clearHistory();
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    Notifications.clearHistory();
                    event.accepted = true;
                }
            }
        }

        ToggleRow {
            width: parent.width
            label: "Do not disturb"
            description: "Popups pause; critical notifications and history keep working."
            checked: Notifications.doNotDisturb
            onToggled: Notifications.toggleDoNotDisturb()
        }

        Text {
            width: parent.width
            visible: Notifications.history.length === 0
            text: "No notifications"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Repeater {
            model: Notifications.history

            delegate: NotificationCard {
                id: historyCard

                required property var modelData

                width: parent.width
                notification: modelData
                historyMode: true
                onDismissed: Notifications.dismissFromHistory(modelData.id)
            }
        }
    }
}
