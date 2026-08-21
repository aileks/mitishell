pragma Singleton

import QtQuick

QtObject {
    property string activeKey: ""
    property var originScreen: null

    function open(key, screen) {
        activeKey = key;
        originScreen = screen;
    }

    function toggle(key, screen) {
        if (activeKey === key && originScreen === screen) {
            close();
            return false;
        }
        activeKey = key;
        originScreen = screen;
        return true;
    }

    function close() {
        activeKey = "";
        originScreen = null;
    }
}
