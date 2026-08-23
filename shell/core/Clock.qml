pragma Singleton

import QtQuick
import "../lib/ClockModel.js" as ClockModel

QtObject {
    id: root

    property date now: new Date()
    readonly property var locale: Qt.locale()
    readonly property string timeFormat: ClockModel.timePattern(
        Config.clock.format,
        withoutSeconds(locale.timeFormat(Locale.ShortFormat)),
    )
    readonly property var today: ({
        "year": now.getFullYear(),
        "month": now.getMonth(),
        "day": now.getDate()
    })

    function withoutSeconds(format) {
        return format.replace(/([:.])?s{1,2}/g, "").replace(/\s+/g, " ").trim();
    }

    property Timer tickTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }
}
