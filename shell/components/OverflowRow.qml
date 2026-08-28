import QtQuick

Item {
    id: root

    default property alias content: contentRow.data
    property alias spacing: contentRow.spacing
    property Component fallback
    property bool animationsEnabled: true
    property bool reducedMotion: false
    property int initialPauseDuration: 1200
    property int endPauseDuration: 900
    property int returnDuration: 180

    readonly property real contentImplicitWidth: contentRow.implicitWidth
    readonly property real overflowDistance: Math.max(0, contentImplicitWidth - width)
    readonly property bool overflow: overflowDistance > 0
    readonly property bool marqueeNeeded: animationsEnabled && !reducedMotion && overflow
    readonly property bool fallbackNeeded: overflow && !marqueeNeeded

    implicitWidth: contentImplicitWidth
    implicitHeight: contentRow.implicitHeight
    clip: true

    function restartMarquee() {
        startTimer.stop();
        marquee.stop();
        contentRow.x = 0;
        if (marqueeNeeded) {
            startTimer.restart();
        }
    }

    onMarqueeNeededChanged: restartMarquee()
    onWidthChanged: restartMarquee()

    Row {
        id: contentRow
        objectName: "overflowContent"

        anchors.verticalCenter: parent.verticalCenter
        visible: !root.fallbackNeeded

        onImplicitWidthChanged: root.restartMarquee()
    }

    Loader {
        id: fallbackLoader
        objectName: "overflowFallback"

        anchors.fill: parent
        active: root.fallbackNeeded && root.fallback !== null
        visible: active
        sourceComponent: root.fallback
    }

    Timer {
        id: startTimer

        interval: 0
        onTriggered: {
            if (root.marqueeNeeded) {
                marquee.start();
            }
        }
    }

    SequentialAnimation {
        id: marquee
        objectName: "overflowMarquee"

        loops: Animation.Infinite

        PauseAnimation {
            duration: root.initialPauseDuration
        }

        NumberAnimation {
            target: contentRow
            property: "x"
            to: -root.overflowDistance
            duration: Math.max(root.initialPauseDuration, root.overflowDistance * 32)
            easing.type: Easing.Linear
        }

        PauseAnimation {
            duration: root.endPauseDuration
        }

        NumberAnimation {
            target: contentRow
            property: "x"
            to: 0
            duration: root.returnDuration
            easing.type: Easing.OutCubic
        }
    }
}
