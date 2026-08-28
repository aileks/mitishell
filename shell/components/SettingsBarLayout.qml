pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/BarModel.js" as BarModel

Column {
    id: root

    property var localLayout: BarModel.clone(Config.bar.layout)
    property string dragId: ""
    property string targetSection: ""
    spacing: Theme.spaceSm

    readonly property var labels: ({
        workspaces: "Workspaces", windowTitle: "Window title", media: "Media",
        system: "System monitor", audio: "Audio", keyboardLayout: "Keyboard layout",
        updates: "Updates", clock: "Clock", tray: "Tray", network: "Network",
        bluetooth: "Bluetooth", quickSettings: "Quick Settings",
        notifications: "Notifications", weather: "Weather", status: "Status",
        power: "Power",
    })

    function save(next) {
        if (JSON.stringify(next) === JSON.stringify(localLayout)) return;
        localLayout = next;
        Settings.setField("bar.layout", JSON.stringify(next));
    }

    function sectionAt(scenePosition) {
        const cards = [leftSection, centerSection, rightSection, hiddenSection];
        const names = ["left", "center", "right", "hidden"];
        for (let index = 0; index < cards.length; index += 1) {
            const local = cards[index].mapFromItem(null, scenePosition);
            if (local.x >= 0 && local.x <= cards[index].width
                    && local.y >= 0 && local.y <= cards[index].height) return names[index];
        }
        return "";
    }

    function finishDrag(scenePosition) {
        const section = sectionAt(scenePosition);
        if (section !== "") save(BarModel.moveTo(localLayout, dragId, section, localLayout[section].length));
        dragId = "";
        targetSection = "";
    }

    Text {
        width: parent.width
        text: "Drag built-in widgets between sections. The center accepts up to three."
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }

    LayoutSection { id: leftSection; sectionName: "left"; title: "Left"; widgets: root.localLayout.left }
    LayoutSection { id: centerSection; sectionName: "center"; title: "Center · " + root.localLayout.center.length + "/3"; widgets: root.localLayout.center }
    LayoutSection { id: rightSection; sectionName: "right"; title: "Right"; widgets: root.localLayout.right }
    LayoutSection { id: hiddenSection; sectionName: "hidden"; title: "Hidden"; widgets: root.localLayout.hidden }

    InlineStatus {
        width: parent.width
        visible: Settings.fieldErrors["bar.layout"] !== undefined
        message: Settings.fieldErrors["bar.layout"] || ""
    }

    component LayoutSection: Rectangle {
        id: sectionRoot
        required property string sectionName
        required property string title
        required property var widgets

        width: root.width
        implicitHeight: sectionContent.implicitHeight + Theme.spaceMd * 2
        radius: Theme.radiusMedium
        color: root.targetSection === sectionName ? Theme.alpha(Theme.blue, 0.12) : Theme.layerInset
        border.width: root.targetSection === sectionName ? 2 : 1
        border.color: root.targetSection === sectionName ? Theme.blue : Theme.borderSubtle

        Column {
            id: sectionContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            Text {
                text: sectionRoot.title
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }

            Flow {
                id: pills
                width: parent.width
                spacing: Theme.spaceXs

                Repeater {
                    model: sectionRoot.widgets
                    delegate: Rectangle {
                        id: pill
                        required property string modelData
                        implicitWidth: label.implicitWidth + Theme.spaceMd * 2
                        implicitHeight: Theme.controlHeightSm
                        radius: Theme.radiusPill
                        color: activeFocus || hover.hovered ? Theme.hoverFill : Theme.layerRaised
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus ? Theme.blue : Theme.borderStrong
                        activeFocusOnTab: true
                        Accessible.name: root.labels[modelData] || modelData
                        Accessible.description: "Control Shift arrows rearrange this bar widget"
                        Accessible.role: Accessible.Button

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: root.labels[pill.modelData] || pill.modelData
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeCaption
                        }

                        HoverHandler { id: hover; cursorShape: Qt.OpenHandCursor }
                        BarReorderGesture {
                            verticalEnabled: true
                            onDragStarted: function(pressScenePosition, scenePosition) {
                                root.dragId = pill.modelData;
                                root.targetSection = root.sectionAt(scenePosition);
                            }
                            onDragMoved: function(scenePosition) { root.targetSection = root.sectionAt(scenePosition); }
                            onDragFinished: function(scenePosition) { root.finishDrag(scenePosition); }
                            onDragCanceled: { root.dragId = ""; root.targetSection = ""; }
                        }

                        Keys.onPressed: function(event) {
                            if (!(event.modifiers & Qt.ControlModifier)
                                    || !(event.modifiers & Qt.ShiftModifier)) return;
                            let direction = "";
                            if (event.key === Qt.Key_Left) direction = "previous";
                            else if (event.key === Qt.Key_Right) direction = "next";
                            else if (event.key === Qt.Key_Up) direction = "previous-section";
                            else if (event.key === Qt.Key_Down) direction = "next-section";
                            if (direction === "") return;
                            root.save(BarModel.moveKeyboard(root.localLayout, pill.modelData, direction));
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Config
        function onBarChanged() { root.localLayout = BarModel.clone(Config.bar.layout); }
    }
}
