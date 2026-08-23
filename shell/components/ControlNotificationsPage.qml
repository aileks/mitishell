pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/NotificationModel.js" as NotificationModel

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

        Text {
            text: "Notifications"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            implicitHeight: dndRow.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            ToggleRow {
                id: dndRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                label: "Do not disturb"
                description: "Popups pause; critical notifications and history keep working."
                checked: Notifications.doNotDisturb
                onToggled: Notifications.toggleDoNotDisturb()
            }
        }

        Row {
            width: parent.width
            visible: Notifications.history.length > 0
            spacing: Theme.spaceMd

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "History"
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }

            Item { width: parent.width - clearAll.implicitWidth - historyLabel.implicitWidth - Theme.spaceMd; height: 1 }

            Rectangle {
                id: clearAll

                anchors.verticalCenter: parent.verticalCenter
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
