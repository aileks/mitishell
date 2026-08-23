pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../lib/NotificationModel.js" as NotificationModel

SurfaceFrame {
    id: root

    required property var notification
    required property bool historyMode
    signal dismissed(bool expired)

    readonly property string avatarValue: notification.appIcon !== ""
        ? notification.appIcon
        : notification.desktopEntry
    readonly property string avatarSource: {
        if (avatarValue === "") {
            return "";
        }
        if (avatarValue.indexOf("/") !== -1
                || avatarValue.indexOf("file:") === 0
                || avatarValue.indexOf("image:") === 0) {
            return avatarValue;
        }
        return Quickshell.iconPath(avatarValue, true);
    }
    readonly property var actionable: notification.live
        ? notification.actions.filter(function(action) {
            return action.identifier !== "default" && action.text !== "";
        })
        : []

    implicitWidth: 360
    implicitHeight: content.implicitHeight + padding * 2
    padding: Theme.spaceMd
    fill: Theme.layerInset
    accent: notification.urgency === 2 ? Theme.red : Theme.pink
    floating: !historyMode

    property Timer expiry: Timer {
        interval: root.notification.timeout
        running: !root.historyMode && root.notification.timeout > 0
        onTriggered: root.dismissed(true)
    }

    Column {
        id: content

        width: parent.width
        spacing: Theme.spaceSm

        Row {
            width: parent.width
            spacing: Theme.spaceMd

            Rectangle {
                width: 42
                height: 42
                radius: Theme.radiusMedium
                color: Theme.alpha(Theme.pink, 0.16)
                border.width: 1
                border.color: Theme.alpha(Theme.pink, 0.42)
                clip: true

                Image {
                    id: avatar

                    anchors.fill: parent
                    anchors.margins: 4
                    source: root.avatarSource
                    sourceSize.width: 38
                    sourceSize.height: 38
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Text {
                    visible: root.avatarSource === "" || avatar.status === Image.Error
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: Theme.pink
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.iconMd
                }
            }

            Column {
                width: parent.width - 42 - dismissButton.width - parent.spacing * 2
                spacing: Theme.spaceXs

                Item {
                    width: parent.width
                    implicitHeight: Math.max(appName.implicitHeight, age.implicitHeight)

                    Text {
                        id: appName

                        anchors.left: parent.left
                        anchors.right: age.left
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.notification.appName !== ""
                            ? root.notification.appName
                            : "Notification"
                        elide: Text.ElideRight
                        color: Theme.pink
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: age

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotificationModel.timeLabel(
                            root.notification.timestamp,
                            Date.now(),
                        )
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
                    maximumLineCount: root.historyMode ? 5 : 3
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            FocusScope {
                id: dismissButton

                width: 28
                height: 28
                activeFocusOnTab: true
                Accessible.name: "Dismiss notification"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: root.dismissed(false)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusPill
                    color: dismissTap.pressed ? Theme.pressedFill
                        : (dismissButton.activeFocus || dismissHover.hovered
                            ? Theme.hoverFill : "transparent")
                    border.width: dismissButton.activeFocus ? 2 : 0
                    border.color: Theme.blue

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeTitle
                    }
                }

                HoverHandler { id: dismissHover }
                TapHandler { id: dismissTap; onTapped: root.dismissed(false) }
                Keys.onReturnPressed: function(event) {
                    root.dismissed(false);
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.dismissed(false);
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            visible: contentImage.status === Image.Ready
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, root.historyMode ? 280 : 240)
            height: width * 0.75
            radius: Theme.radiusMedium
            color: Theme.layerRaised
            border.width: 1
            border.color: Theme.borderSubtle
            clip: true

            Image {
                id: contentImage

                anchors.fill: parent
                source: root.notification.image
                sourceSize.width: 280
                sourceSize.height: 210
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Flow {
            width: parent.width
            visible: root.actionable.length > 0
            spacing: Theme.spaceSm

            Repeater {
                model: root.actionable

                delegate: ActionButton {
                    required property var modelData

                    implicitWidth: Math.max(72, implicitContentWidth)
                    label: modelData.text
                    accent: Theme.pink
                    onActivated: {
                        Notifications.invokeAction(
                            root.notification.liveId,
                            modelData.identifier,
                        );
                        root.dismissed(false);
                    }

                    readonly property real implicitContentWidth: label.length * 8
                }
            }
        }
    }

    TapHandler {
        enabled: !root.historyMode
        acceptedButtons: Qt.LeftButton
        onTapped: root.dismissed(false)
    }
}
