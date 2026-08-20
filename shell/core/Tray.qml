pragma Singleton

import QtQuick
import Quickshell.Services.SystemTray

QtObject {
    readonly property var items: activeItems()
    readonly property bool available: items.length > 0

    function activeItems() {
        const active = [];
        const values = SystemTray.items.values;

        for (let index = 0; index < values.length; index++) {
            const item = values[index];
            if (item.status !== Status.Passive) {
                active.push(item);
            }
        }

        active.sort(function(left, right) {
            return label(left).localeCompare(label(right));
        });
        return active;
    }

    function label(item) {
        return item.tooltipTitle || item.title || item.id || "Tray item";
    }

    function description(item) {
        return item.tooltipDescription || "";
    }
}
