pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"
import "../lib/NetworkModel.js" as NetworkModel

Flickable {
    id: root

    readonly property bool ethernetAvailable: Network.ethernet !== null
        && Network.ethernet.available
    readonly property string ethernetState: ethernetAvailable
        ? Network.ethernet.state : "unavailable"
    readonly property bool wifiAvailable: Network.wifi !== null && Network.wifi.available
    readonly property bool wifiEnabled: wifiAvailable && Network.wifi.enabled
    readonly property string wifiState: wifiAvailable
        ? Network.wifi.state : "unavailable"
    readonly property var wifiStations: wifiAvailable ? Network.wifi.stations : []
    readonly property var savedWifi: wifiAvailable ? Network.wifi.saved : []

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: {
        if (visible) {
            Network.refresh();
            pollTimer.restart();
        } else {
            pollTimer.stop();
        }
    }

    property Timer pollTimer: Timer {
        interval: 4000
        repeat: true
        onTriggered: Network.refresh()
    }

    Column {
        id: content

        width: root.width
        spacing: Theme.spaceMd

        SurfaceHeader {
            width: parent.width
            title: "Network"
            accent: Theme.cyan
        }

        InlineStatus {
            width: parent.width
            visible: Network.error !== ""
            message: Network.error
        }

        Rectangle {
            width: parent.width
            visible: root.ethernetAvailable
            implicitHeight: ethernetContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: ethernetContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceXs

                Text {
                    text: "Ethernet"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.ethernetState === "connected"
                        ? "Connected" : "Cable unplugged"
                    color: root.ethernetState === "connected"
                        ? Theme.green : Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Rectangle {
            width: parent.width
            visible: root.wifiAvailable
            implicitHeight: wifiContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: wifiContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                ToggleRow {
                    width: parent.width
                    accent: Theme.cyan
                    label: "Wi-Fi"
                    description: Network.wifiBusy
                        ? "Changing Wi-Fi state"
                        : NetworkModel.stateLabel(root.wifiState)
                    checked: root.wifiEnabled
                    enabled: !Network.wifiBusy
                    onToggled: Network.setWifiEnabled(!root.wifiEnabled)
                }

                Text {
                    width: parent.width
                    visible: root.wifiEnabled && root.wifiStations.length === 0
                    text: "No networks in range"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }

                Repeater {
                    visible: root.wifiEnabled
                    model: NetworkModel.listableStations(
                        root.wifiStations, root.savedWifi)

                    delegate: Column {
                        id: stationEntry

                        required property var modelData

                        width: wifiContent.width
                        spacing: Theme.spaceXs

                        Rectangle {
                            id: stationRow

                            width: parent.width
                            height: 40
                            radius: Theme.radiusMedium
                            color: stationEntry.modelData.inUse || joinRow.ssid === stationEntry.modelData.ssid
                                || stationRow.activeFocus || stationHover.hovered
                                ? Theme.overlay : "transparent"
                            border.width: stationRow.activeFocus ? 2 : 0
                            border.color: Theme.blue
                            activeFocusOnTab: true
                            Accessible.name: stationEntry.modelData.ssid
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: stationRow.choose()

                            function choose() {
                                if (stationEntry.modelData.security === "open") {
                                    Network.connectToNetwork(
                                        stationEntry.modelData.ssid, "", false);
                                } else if (stationEntry.modelData.security === "enterprise") {
                                    Network.error = "Enterprise networks need sign-in that mitishell does not support";
                                } else {
                                    joinRow.openFor(stationEntry.modelData.ssid);
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spaceMd
                                anchors.right: stationMeta.left
                                anchors.rightMargin: Theme.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spaceSm

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: stationEntry.modelData.ssid
                                    elide: Text.ElideRight
                                    width: parent.width - bars.width - Theme.spaceSm
                                    color: stationEntry.modelData.inUse
                                        ? Theme.green : Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeBody
                                }

                                SignalBars {
                                    id: bars

                                    anchors.verticalCenter: parent.verticalCenter
                                    strength: stationEntry.modelData.signal
                                }
                            }

                            Row {
                                id: stationMeta

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spaceMd
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spaceSm

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: stationEntry.modelData.saved
                                    text: "saved"
                                    color: Theme.textMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: NetworkModel.securityLabel(
                                        stationEntry.modelData.security)
                                    color: stationEntry.modelData.security === "open"
                                        ? Theme.textMuted : Theme.blue
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: stationEntry.modelData.saved
                                    width: forgetLabel.implicitWidth + Theme.spaceLg * 2
                                    height: 24
                                    radius: Theme.radiusPill
                                    color: forgetHover.hovered ? Theme.overlay : "transparent"
                                    border.width: 1
                                    border.color: Theme.borderStrong

                                    Text {
                                        id: forgetLabel

                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: Theme.textMuted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontSizeCaption
                                    }

                                    HoverHandler {
                                        id: forgetHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: Network.forget(stationEntry.modelData.ssid)
                                    }
                                }
                            }

                            HoverHandler {
                                id: stationHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: stationRow.choose()
                            }

                            Keys.onReturnPressed: function(event) {
                                stationRow.choose();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function(event) {
                                stationRow.choose();
                                event.accepted = true;
                            }
                        }

                        // Inline join form for secured networks.
                        Column {
                            id: joinRow

                            property string ssid: ""

                            width: parent.width
                            visible: ssid === stationEntry.modelData.ssid
                            spacing: Theme.spaceXs

                            function openFor(ssid) {
                                joinRow.ssid = ssid;
                                passwordField.text = "";
                                passwordField.forceActiveFocus(Qt.TabFocusReason);
                            }

                            Controls.TextField {
                                id: passwordField

                                width: parent.width
                                echoMode: TextInput.Password
                                placeholderText: "Password for " + joinRow.ssid
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSizeBody
                                activeFocusOnTab: true
                                background: Rectangle {
                                    radius: Theme.radiusSmall
                                    color: Theme.background
                                    border.width: passwordField.activeFocus ? 2 : 1
                                    border.color: passwordField.activeFocus
                                        ? Theme.blue : Theme.borderStrong
                                }

                                onAccepted: joinRow.submit()
                            }

                            Row {
                                spacing: Theme.spaceSm

                                Rectangle {
                                    width: joinLabel.implicitWidth + Theme.spaceLg * 2
                                    height: 30
                                    radius: Theme.radiusPill
                                    color: joinHover.hovered ? Theme.overlay : Theme.orange

                                    Text {
                                        id: joinLabel

                                        anchors.centerIn: parent
                                        text: Network.joining ? "Joining" : "Join"
                                        color: Theme.background
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Font.DemiBold
                                    }

                                    HoverHandler {
                                        id: joinHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: joinRow.submit()
                                    }
                                }
                            }

                            function submit() {
                                Network.connectToNetwork(joinRow.ssid, passwordField.text, false);
                            }
                        }
                    }
                }
            }
        }

        // Hidden networks join by name.
        Rectangle {
            width: parent.width
            visible: root.wifiAvailable && root.wifiEnabled
            implicitHeight: hiddenContent.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radiusMedium
            color: Theme.container

            Column {
                id: hiddenContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceMd
                spacing: Theme.spaceSm

                Text {
                    text: "Hidden network"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Font.DemiBold
                }

                Controls.TextField {
                    id: hiddenName

                    width: parent.width
                    placeholderText: "Network name"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                    activeFocusOnTab: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.background
                        border.width: hiddenName.activeFocus ? 2 : 1
                        border.color: hiddenName.activeFocus ? Theme.blue : Theme.borderStrong
                    }
                }

                Controls.TextField {
                    id: hiddenPassword

                    width: parent.width
                    echoMode: TextInput.Password
                    placeholderText: "Password (empty for open networks)"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                    activeFocusOnTab: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.background
                        border.width: hiddenPassword.activeFocus ? 2 : 1
                        border.color: hiddenPassword.activeFocus ? Theme.blue : Theme.borderStrong
                    }

                    onAccepted: {
                        Network.connectToNetwork(hiddenName.text, hiddenPassword.text, true);
                    }
                }
            }
        }
    }
}
