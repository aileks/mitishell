import QtQuick

DragHandler {
    id: root

    property point lastScenePosition: Qt.point(0, 0)
    property bool sessionActive: false

    signal dragStarted(point pressScenePosition, point scenePosition)
    signal dragMoved(point scenePosition)
    signal dragFinished(point scenePosition)
    signal dragCanceled()

    target: null
    dragThreshold: 4
    acceptedButtons: Qt.LeftButton
    xAxis.enabled: true
    yAxis.enabled: false
    cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    onActiveChanged: {
        if (active) {
            root.sessionActive = true;
            root.lastScenePosition = centroid.scenePosition;
            root.dragStarted(centroid.scenePressPosition, centroid.scenePosition);
        } else if (root.sessionActive) {
            Qt.callLater(() => {
                if (!root.sessionActive || root.active) return;
                root.sessionActive = false;
                root.dragFinished(root.lastScenePosition);
            });
        }
    }

    onActiveTranslationChanged: {
        if (!active) return;
        root.lastScenePosition = centroid.scenePosition;
        root.dragMoved(centroid.scenePosition);
    }

    onCanceled: {
        if (!root.sessionActive) return;
        root.sessionActive = false;
        root.dragCanceled();
    }

    onEnabledChanged: {
        if (enabled || !root.sessionActive) return;
        root.sessionActive = false;
        root.dragCanceled();
    }
}
