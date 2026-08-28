pragma Singleton

import QtQuick

QtObject {
    id: root

    // Which page the Settings surface shows. Summoning entry points choose the
    // starting page (the bar button always resets to overview); the rail and the
    // IPC can move it while open.
    property string page: "overview"

    readonly property var pages: [
        "overview", "audio", "display", "network", "bluetooth", "system",
    ]

    function selectPage(next) {
        if (pages.indexOf(next) !== -1) {
            page = next;
        }
    }
}
