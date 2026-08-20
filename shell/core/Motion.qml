pragma Singleton

import QtQuick

QtObject {
    readonly property int instant: 80
    readonly property int quick: 120
    readonly property int normal: 180
    readonly property int emphasized: 240
    readonly property int entrance: 280

    function duration(milliseconds) {
        return Config.motion.enabled && !Config.motion.reduced ? milliseconds : 0;
    }
}
