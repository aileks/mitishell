pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/FontModel.js" as FontModel

// Modal font chooser layered over the settings card. One slot opens at a
// time; Escape, the back button, or choosing a family closes it, and the
// choice applies through `config set` like any other setting.
Rectangle {
    id: root

    readonly property string slot: Fonts.pickerSlot
    readonly property bool active: slot !== ""

    property string query: ""
    property var choices: []

    visible: opacity > 0
    opacity: active ? 1 : 0
    color: Theme.layerRaised
    radius: Theme.radiusMedium
    border.width: 1
    border.color: Theme.borderSubtle

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.duration(Motion.quick)
            easing.type: Motion.easingStandard
        }
    }

    function rebuild() {
        const families = root.slot === "mono" ? Fonts.nerdFamilies : Fonts.families;
        const built = root.slot === "mono"
            ? FontModel.monoChoices(families)
            : FontModel.standardChoices(families);
        choices = FontModel.filterChoices(built, query);
    }

    function choose(index) {
        if (index < 0 || index >= choices.length) return;
        Settings.setField(
            root.slot === "mono" ? "font.monoFamily" : "font.family",
            choices[index].value);
        Fonts.closePicker();
    }

    onSlotChanged: {
        if (root.slot !== "") {
            query = "";
            rebuild();
            Qt.callLater(function() {
                searchInput.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    Connections {
        target: Fonts
        function onFamiliesChanged() { root.rebuild(); }
        function onNerdFamiliesChanged() { root.rebuild(); }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: Fonts.closePicker()
    }

    // Takes the press on any picker space the controls above don't claim,
    // with an exclusive grab so a click can never reach the interactive
    // page beneath the layer.
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceLg
        spacing: Theme.spaceMd

        Row {
            id: headerRow

            width: parent.width
            height: Theme.controlHeight
            spacing: Theme.spaceMd

            IconButton {
                id: backButton

                anchors.verticalCenter: parent.verticalCenter
                iconSource: Icons.chevronLeft
                accessibleName: "Back to settings"
                onClicked: Fonts.closePicker()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.spacing - backButton.width
                text: root.slot === "mono" ? "Monospace font" : "Standard font"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: searchBox

            width: parent.width
            height: Theme.controlHeight
            color: Theme.background
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Theme.blue : Theme.borderStrong

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd
                clip: true
                text: root.query
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: true
                Accessible.name: "Search fonts"
                onTextEdited: {
                    root.query = text;
                    root.rebuild();
                }
                onAccepted: {
                    if (list.currentIndex >= 0) {
                        root.choose(list.currentIndex);
                    }
                }
                Keys.onDownPressed: function(event) {
                    list.forceActiveFocus(Qt.TabFocusReason);
                    list.positionViewAtIndex(0, ListView.Contain);
                    event.accepted = true;
                }

                Text {
                    anchors.fill: parent
                    visible: searchInput.text === ""
                    text: "Search fonts…"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBodySmall
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - headerRow.height - searchBox.height
                - 2 * parent.spacing

            ListView {
                id: list

                anchors.fill: parent
                model: root.choices
                clip: true
                spacing: Theme.spaceXs
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true

                Keys.onReturnPressed: function(event) {
                    root.choose(currentIndex);
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.choose(currentIndex);
                    event.accepted = true;
                }
                Keys.onUpPressed: function(event) {
                    if (currentIndex === 0) {
                        searchInput.forceActiveFocus(Qt.TabFocusReason);
                        event.accepted = true;
                    }
                    // Otherwise the built-in navigation moves the selection.
                }

                delegate: Rectangle {
                    id: optionRow

                    required property var modelData
                    required property int index

                    readonly property bool active: root.slot === "mono"
                        ? Config.font.monoFamily === modelData.value
                        : Config.font.family === modelData.value
                    readonly property string previewFamily: modelData.value !== ""
                        ? modelData.value
                        : (root.slot === "mono" ? "Adwaita Mono" : Theme.systemFont)

                    width: list.width
                    height: Theme.controlHeightLg
                    radius: Theme.radiusMedium
                    color: active ? Theme.alpha(Theme.blue, 0.14)
                        : (optionRow.activeFocus || rowHover.hovered ? Theme.hoverFill : "transparent")
                    border.width: optionRow.activeFocus ? 2 : 0
                    border.color: Theme.blue
                    activeFocusOnTab: true
                    Accessible.name: modelData.label
                    Accessible.role: Accessible.Button

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceLg
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceLg
                        anchors.verticalCenter: parent.verticalCenter
                        text: optionRow.modelData.label
                        color: optionRow.active ? Theme.textBright : Theme.text
                        font.family: optionRow.previewFamily
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }

                    IconLabel {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceLg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: optionRow.active
                        value: Icons.check
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) list.currentIndex = optionRow.index;
                        }
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.choose(optionRow.index)
                    }

                    Keys.onReturnPressed: function(event) {
                        root.choose(optionRow.index);
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        root.choose(optionRow.index);
                        event.accepted = true;
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.spaceSm
                visible: root.choices.length === 0 && Fonts.error === ""

                IconLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: Icons.searchOff
                    size: 32
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No fonts match “" + root.query + "”"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeTitle
                    wrapMode: Text.Wrap
                }
            }

            InlineStatus {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Fonts.error !== ""
                message: Fonts.error
                textSize: Theme.fontSizeCaption
            }
        }
    }
}
