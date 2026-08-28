pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// The bell popover: recent history with actions, quick dismiss, and the
// do-not-disturb switch, anchored under the bar widget.
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

            SurfaceHeader {
                id: heading

                width: parent.width - clearAll.width - parent.spacing
                title: "Notifications"
                description: Notifications.unread > 0
                    ? Notifications.unread + " unread"
                    : "Recent activity"
                accent: Theme.orange
            }

            ActionButton {
                id: clearAll

                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.history.length > 0
                implicitWidth: 82
                implicitHeight: Theme.controlHeightSm
                label: "Clear all"
                accent: Theme.orange
                onActivated: Notifications.clearHistory()
            }
        }

        SectionCard {
            visible: Notifications.historyError !== ""
            width: parent.width
            title: "History unavailable"
            accent: Theme.yellow

            Text {
                width: parent.width
                text: Notifications.historyError
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
                wrapMode: Text.Wrap
            }
        }

        ToggleRow {
            width: parent.width
            label: "Do not disturb"
            checked: Notifications.doNotDisturb
            onToggled: Notifications.toggleDoNotDisturb()
        }

        StateMessage {
            width: parent.width
            visible: Notifications.history.length === 0
            title: "No notifications"
            accent: Theme.orange
        }

        Repeater {
            model: Notifications.history

            delegate: NotificationCard {
                id: historyCard

                required property var modelData

                width: parent.width
                notification: modelData
                historyMode: true
                onDismissed: Notifications.dismissFromHistory(modelData.recordId)
            }
        }
    }
}
