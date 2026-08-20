pragma Singleton

import QtQuick

QtObject {
    id: root

    property date now: new Date()
    readonly property var locale: Qt.locale()
    readonly property var today: ({
        "year": now.getFullYear(),
        "month": now.getMonth(),
        "day": now.getDate()
    })

    property Timer tickTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }
}
