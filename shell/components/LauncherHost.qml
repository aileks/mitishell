pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../lib/Calculator.js" as Calculator
import "../lib/LauncherModel.js" as LauncherModel
import "../lib/SearchModel.js" as SearchModel

SearchSurface {
    id: root

    surfaceKey: "launcher"
    accent: Theme.orange
    placeholder: "Launcher"
    emptyMessage: query.charAt(0) === ":" ? "Clipboard history is empty"
        : (query.charAt(0) === "=" ? "Invalid expression" : "No matching applications")
    warning: Launcher.persistenceError
    rowDelegate: launcherRow

    // Walker parity: launcher providers return at most 30 results.
    readonly property int resultLimit: 30

    function rebuild() {
        const calculation = Calculator.fromQuery(query);
        if (calculation !== null) {
            results = [{
                id: "calculator",
                source: calculation.ok ? "calculator" : "calculator-error",
                label: calculation.ok ? calculation.text : calculation.error,
                detail: calculation.ok ? "Copy result" : "Calculator",
                icon: calculation.ok ? Icons.check
                    : (calculation.pending ? Icons.ellipsis : Icons.circleAlert),
                keywords: [],
                actionable: calculation.ok,
                tone: calculation.ok ? "" : (calculation.pending ? "muted" : "error"),
            }];
            return;
        }

        if (query.charAt(0) === ":") {
            results = clipboardResults(query.slice(1));
            return;
        }
        if (query.charAt(0) === ">") {
            results = runnerResults(query.slice(1));
            return;
        }

        const actions = Launcher.nativeActions();
        const entries = Launcher.applications.concat(actions);
        results = query.trim() === ""
            ? LauncherModel.blankEntries(Launcher.applications, actions, Launcher.recents).slice(0, resultLimit)
            : SearchModel.rank(entries, query, resultLimit);
    }

    function clipboardResults(needle) {
        const rows = Clipboard.entries.map(function(text, index) {
            return {
                id: "clipboard:" + index,
                source: "clipboard",
                label: Clipboard.preview(text),
                detail: "Copy",
                icon: Icons.clipboard,
                keywords: [text],
                text: text,
            };
        });
        const ranked = needle.trim() === ""
            ? rows : SearchModel.rank(rows, needle, resultLimit);
        if (Clipboard.entries.length > 0) {
            ranked.push({
                id: "clipboard-clear",
                source: "clipboard-clear",
                label: "Clear clipboard history",
                detail: "Clipboard",
                icon: Icons.trashCan,
                keywords: ["clipboard", "clear", "wipe"],
            });
        }
        return ranked;
    }

    function runnerResults(command) {
        const text = command.trim();
        if (text === "") {
            return [{
                id: "runner",
                source: "runner-pending",
                label: "Type a command",
                detail: "Run command",
                icon: Icons.consoleIcon,
                keywords: [],
                actionable: false,
                tone: "muted",
            }];
        }
        return [{
            id: "runner",
            source: "runner",
            label: text,
            detail: "Run command",
            icon: Icons.consoleIcon,
            keywords: [],
            text: text,
        }];
    }

    onOpened: {
        if (Launcher.pendingQuery !== "") {
            const seeded = Launcher.pendingQuery;
            Launcher.pendingQuery = "";
            query = seeded;
        }
        rebuild();
    }
    onQueryChanged: rebuild()
    onActivateRequested: function(entry) { Launcher.activate(entry, root.modelData); }
    onDeleteRequested: function(entry) {
        if (entry.source === "clipboard") Clipboard.removeEntry(entry.text);
    }

    Connections {
        target: Launcher
        function onApplicationsChanged() { root.rebuild(); }
        function onRecentsChanged() { root.rebuild(); }
        function onPersistenceErrorChanged() { root.rebuild(); }
    }

    Connections {
        target: Clipboard
        function onEntriesChanged() { root.rebuild(); }
        function onPersistenceErrorChanged() { root.rebuild(); }
    }

    Connections {
        target: Notifications
        function onDoNotDisturbChanged() { root.rebuild(); }
    }

    Connections {
        target: NightLight
        function onAvailableChanged() { root.rebuild(); }
        function onEnabledChanged() { root.rebuild(); }
    }

    Connections {
        target: Reminders
        function onAvailableChanged() { root.rebuild(); }
    }

    Connections {
        target: Network
        function onStateChanged() { root.rebuild(); }
    }

    Connections {
        target: Bluetooth
        function onStateChanged() { root.rebuild(); }
        function onAdapterChanged() { root.rebuild(); }
    }

    Component {
        id: launcherRow

        Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool selected: ListView.view.currentIndex === index
            readonly property bool actionable: modelData.actionable !== false

            width: ListView.view.width
            height: Theme.controlHeightLg
            color: !row.actionable ? "transparent"
                : (selected ? Theme.alpha(Theme.orange, 0.18)
                    : (hover.hovered ? Theme.hoverFill : "transparent"))
            border.width: selected && row.actionable ? 1 : 0
            border.color: Theme.orange
            Accessible.name: modelData.label + ", " + modelData.detail
            Accessible.role: actionable ? Accessible.Button : Accessible.StaticText
            Accessible.onPressAction: root.activateIndex(index)

            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd

                Image {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconMd
                    height: Theme.iconMd
                    visible: row.modelData.source === "application"
                    source: visible
                        ? Quickshell.iconPath(row.modelData.icon, true)
                        : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                IconLabel {
                    id: actionIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.source !== "application"
                    value: row.modelData.icon
                    size: Theme.iconMd
                }

                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: Theme.spaceMd
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.label
                        color: row.actionable ? Theme.textBright
                            : (row.modelData.tone === "error" ? Theme.red : Theme.textMuted)
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: row.modelData.detail
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        elide: Text.ElideRight
                    }
                }
            }

            HoverHandler {
                id: hover
                enabled: row.actionable
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                enabled: row.actionable
                onTapped: root.activateIndex(row.index)
            }
            onSelectedChanged: if (selected) ListView.view.positionViewAtIndex(index, ListView.Contain)
        }
    }
}
