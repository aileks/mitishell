pragma Singleton

import QtQuick

QtObject {
    id: root

    // Which page the control center shows. Summoning entry points choose the
    // starting page (the bar island always resets to home); the rail and the
    // IPC can move it while open.
    property string page: "home"

    readonly property var pages: ["home", "audio", "media", "display", "notifications"]

    function selectPage(next) {
        if (pages.indexOf(next) !== -1) {
            page = next;
        }
    }
}
