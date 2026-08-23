pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/NotificationModel.js" as NotificationModel

Rectangle {
    id: root

    required property var notification
    required property bool historyMode
    signal dismissed

    implicitWidth: 360
    implicitHeight: content.implicitHeight + Theme.spaceMd * 2
    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: 1
    border.color: root.notification.urgency === 2 ? Theme.red : Theme.overlay

    // Critical popups stay until dismissed; everything else expires.
    property Timer expiry: Timer {
        interval: root.notification.timeout
        running: !root.historyMode && root.notification.timeout > 0
        onTriggered: root.dismissed()
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceXs

        Item {
            width: parent.width
            implicitHeight: heading.implicitHeight

            Text {
                id: heading

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.notification.appName !== "" ? root.notification.appName : "Notification"
                elide: Text.ElideRight
                width: parent.width - age.width - Theme.spaceSm
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }

            Text {
                id: age

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: NotificationModel.timeLabel(root.notification.timestamp, Date.now())
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
            }
        }

        Text {
            width: parent.width
            visible: root.notification.summary !== ""
            text: root.notification.summary
            elide: Text.ElideRight
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: root.notification.body !== ""
            text: root.notification.body
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBody
        }

        Row {
            visible: root.notification.actions.length > 1
            spacing: Theme.spaceSm

            Repeater {
                model: {
                    const actionable = root.notification.actions.filter(function(action) {
                        return action.identifier !== "default" && action.text !== "";
                    });
                    return actionable;
                }

                delegate: Rectangle {
                    id: actionButton

                    required property var modelData

                    width: actionLabel.implicitWidth + Theme.spaceLg * 2
                    height: 30
                    radius: Theme.radiusPill
                    color: activeFocus || hover.hovered ? Theme.overlay : Theme.container
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.blue : Theme.overlay
                    activeFocusOnTab: true
                    Accessible.name: actionButton.modelData.text
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: activated()

                    function activated() {
                        Notifications.invokeAction(
                            root.notification.id, actionButton.modelData.identifier);
                        root.dismissed();
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: actionButton.modelData.text
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                    }

                    HoverHandler {
                        id: hover
                    }

                    TapHandler {
                        onTapped: actionButton.activated()
                    }

                    Keys.onReturnPressed: function(event) {
                        actionButton.activated();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        actionButton.activated();
                        event.accepted = true;
                    }
                }
            }
        }
    }

    // Clicking a popup's empty space dismisses it; history cards dismiss
    // from their explicit row action instead.
    TapHandler {
        enabled: !root.historyMode
        onTapped: root.dismissed()
    }
}
