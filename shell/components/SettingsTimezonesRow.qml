pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// The clock.timezones editor: one removable pill per configured zone plus a
// text entry for new IANA zone names. Writes go through the CLI's validated
// `clock.timezones`; Go's rejection reason surfaces inline.
Column {
    id: root

    readonly property string error: Settings.fieldErrors["clock.timezones"] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Text {
        text: "Timezones"
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        width: parent.width
        text: "e.g. Europe/Berlin"
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceSm

        Repeater {
            model: Config.clock.timezones

            delegate: Rectangle {
                id: zonePill

                required property string modelData

                width: zonePillRow.implicitWidth + Theme.spaceMd * 2
                height: 26
                radius: Theme.radiusPill
                color: zonePillHover.hovered || zonePill.activeFocus
                    ? Theme.hoverFill : Theme.layerInset
                border.width: zonePill.activeFocus ? 2 : 1
                border.color: zonePill.activeFocus ? Theme.blue : Theme.borderStrong
                activeFocusOnTab: true
                Accessible.name: "Remove timezone " + zonePill.modelData
                Accessible.role: Accessible.Button
                Accessible.onPressAction: remove()

                function remove() {
                    const remaining = Config.clock.timezones.filter(function(zone) {
                        return zone !== zonePill.modelData;
                    });
                    Settings.setField("clock.timezones", JSON.stringify(remaining));
                }

                Row {
                    id: zonePillRow

                    anchors.centerIn: parent
                    spacing: Theme.spaceXs

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: zonePill.modelData
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }

                    IconLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        value: Icons.close
                        size: 14
                    }
                }

                HoverHandler { id: zonePillHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        zonePill.forceActiveFocus(Qt.TabFocusReason);
                        zonePill.remove();
                    }
                }
                Keys.onReturnPressed: function(event) {
                    zonePill.remove();
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    zonePill.remove();
                    event.accepted = true;
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 30
        radius: Theme.radiusSmall
        color: Theme.layerInset
        border.width: zoneInput.activeFocus ? 2 : 1
        border.color: zoneInput.activeFocus ? Theme.blue : Theme.borderStrong

        TextInput {
            id: zoneInput

            anchors.fill: parent
            anchors.leftMargin: Theme.spaceSm
            anchors.rightMargin: Theme.spaceSm
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textBright
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
            activeFocusOnTab: true
            Accessible.name: "Add timezone"

            Text {
                anchors.fill: parent
                visible: zoneInput.text === ""
                text: "Europe/Berlin"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
                verticalAlignment: TextInput.AlignVCenter
            }

            onAccepted: {
                const zone = text.trim();
                if (zone === "") {
                    return;
                }
                const updated = Config.clock.timezones.slice();
                updated.push(zone);
                Settings.setField("clock.timezones", JSON.stringify(updated));
                text = "";
            }
        }
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }
}
