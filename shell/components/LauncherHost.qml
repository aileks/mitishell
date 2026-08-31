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
    placeholder: activeMenuId === "root" ? "Launcher" : activeMenuLabel()
    emptyMessage: query.charAt(0) === ":" ? "Clipboard history is empty"
        : (query.charAt(0) === "=" ? "Invalid expression"
            : (activeMenuId === "root" ? "No matching applications" : "No matching actions"))
    warning: Launcher.persistenceError || Clipboard.persistenceError || DesktopActions.error
    backEnabled: activeMenuId !== "root"
    rowDelegate: launcherRow

    property string activeMenuId: "root"

    // Walker parity: launcher providers return at most 30 results.
    readonly property int resultLimit: 30

    function rebuild() {
        const actions = Launcher.nativeActions();
        if (activeMenuId !== "root") {
            activeMenuId = LauncherModel.resolveMenuId(
                actions, activeMenuId, "action:desktop-actions");
        }
        const atRoot = activeMenuId === "root";
        const calculation = atRoot ? Calculator.fromQuery(query) : null;
        if (atRoot && calculation !== null) {
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

        if (atRoot && query.charAt(0) === ":") {
            results = clipboardResults(query.slice(1));
            return;
        }
        if (atRoot && query.charAt(0) === ">") {
            results = runnerResults(query.slice(1));
            return;
        }

        if (query.trim() === "") {
            const children = LauncherModel.childEntries(actions, activeMenuId);
            results = atRoot
                ? LauncherModel.blankEntries(
                    Launcher.applications, children, Launcher.recents).slice(0, resultLimit)
                : children.slice(0, resultLimit);
            return;
        }
        const searchable = LauncherModel.searchableActions(actions, activeMenuId);
        const entries = atRoot ? Launcher.applications.concat(searchable) : searchable;
        results = SearchModel.rank(entries, query, resultLimit);
    }

    function activeMenuLabel() {
        const actions = Launcher.nativeActions();
        for (let index = 0; index < actions.length; index++) {
            if (actions[index].id === activeMenuId) return actions[index].label;
        }
        return "Actions";
    }

    function openMenu(entry) {
        activeMenuId = entry.id;
        query = "";
        rebuild();
        focusSearch();
    }

    function goBack() {
        const actions = Launcher.nativeActions();
        let parent = "root";
        for (let index = 0; index < actions.length; index++) {
            if (actions[index].id === activeMenuId) {
                parent = actions[index].parent || "root";
                break;
            }
        }
        activeMenuId = parent;
        query = "";
        rebuild();
        focusSearch();
    }

    function clipboardResults(needle) {
        const rows = Clipboard.entries.map(function(entry, index) {
            return {
                id: "clipboard:" + entry.id,
                source: "clipboard",
                label: Clipboard.preview(entry),
                detail: Clipboard.detail(entry),
                icon: Icons.clipboard,
                keywords: Clipboard.keywords(entry),
                clipboardEntry: entry,
            };
        });
        // Leave one row for the clear action so the provider stays at 30.
        const cap = resultLimit - 1;
        const ranked = (needle.trim() === ""
            ? rows : SearchModel.rank(rows, needle, cap)).slice(0, cap);
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
        activeMenuId = "root";
        DesktopActions.refresh();
        if (Launcher.pendingMenuId !== "") {
            activeMenuId = Launcher.pendingMenuId;
            Launcher.pendingMenuId = "";
            query = "";
        } else if (Launcher.pendingQuery !== "") {
            const seeded = Launcher.pendingQuery;
            Launcher.pendingQuery = "";
            query = seeded;
        }
        rebuild();
    }
    onFullyClosed: Launcher.surfaceFullyClosed()
    onQueryChanged: rebuild()
    onActivateRequested: function(entry) {
        if (entry.source === "menu") {
            root.openMenu(entry);
        } else {
            Launcher.activate(entry, root.modelData);
        }
    }
    onBackRequested: goBack()
    onDeleteRequested: function(entry) {
        if (entry.source === "clipboard") Clipboard.removeEntry(entry.clipboardEntry.id);
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

    Connections {
        target: DesktopActions
        function onScreenshotModesChanged() { root.rebuild(); }
        function onOcrAvailableChanged() { root.rebuild(); }
        function onQrAvailableChanged() { root.rebuild(); }
        function onRecordingModesChanged() { root.rebuild(); }
        function onRecordingActiveChanged() { root.rebuild(); }
        function onPowerProfilesChanged() { root.rebuild(); }
        function onFirmwareAvailableChanged() { root.rebuild(); }
        function onErrorChanged() { root.rebuild(); }
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

                Item {
                    id: leadingVisual

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconMd
                    height: Theme.iconMd

                    Image {
                        anchors.fill: parent
                        visible: row.modelData.source === "application"
                        source: visible
                            ? Quickshell.iconPath(row.modelData.icon, true)
                            : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Image {
                        anchors.fill: parent
                        visible: row.modelData.source === "clipboard"
                            && row.modelData.clipboardEntry.kind === "image"
                        source: visible ? row.modelData.clipboardEntry.image : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    IconLabel {
                        anchors.fill: parent
                        visible: row.modelData.source !== "application"
                            && !(row.modelData.source === "clipboard"
                                && row.modelData.clipboardEntry.kind === "image")
                        value: row.modelData.icon
                        size: Theme.iconMd
                    }
                }

                Column {
                    anchors.left: leadingVisual.right
                    anchors.leftMargin: Theme.spaceMd
                    anchors.right: menuChevron.visible ? menuChevron.left : parent.right
                    anchors.rightMargin: menuChevron.visible ? Theme.spaceSm : 0
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

                IconLabel {
                    id: menuChevron

                    visible: row.modelData.source === "menu"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    value: Icons.chevronRight
                    size: Theme.iconSm
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
        }
    }
}
