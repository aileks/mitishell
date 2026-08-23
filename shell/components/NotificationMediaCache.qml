import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Notification images can be transient image:// providers or theme icons.
// Render them inside the shell, then hand a private temporary file to the
// companion for durable storage.
Item {
    id: root

    required property var screen
    readonly property bool active: Notifications.popupScreenName === screen.name
    readonly property var task: active && Notifications.mediaQueue.length > 0
        ? Notifications.mediaQueue[0]
        : null
    readonly property string taskSource: task === null ? "" : String(task.source || "")
    readonly property string resolvedSource: {
        if (taskSource === "") {
            return "";
        }
        if (taskSource.indexOf("/") !== -1
                || taskSource.indexOf("file:") === 0
                || taskSource.indexOf("image:") === 0) {
            return taskSource;
        }
        return Quickshell.iconPath(taskSource, true);
    }
    property bool capturing: false
    property var captureTask: null
    property string importPayload: ""
    property var importingTask: null

    x: -512
    y: -512
    width: 256
    height: 256
    visible: active

    function failTask(failedTask) {
        if (failedTask !== null) {
            Notifications.completeMediaCapture(
                failedTask.recordId,
                failedTask.role,
                "",
            );
        }
        capturing = false;
        captureTask = null;
        Qt.callLater(captureCurrent);
    }

    function captureCurrent() {
        if (task === null || media.status !== Image.Ready || capturing) {
            return;
        }
        capturing = true;
        captureTask = task;
        const runtimeRoot = Quickshell.env("XDG_RUNTIME_DIR");
        if (runtimeRoot === "") {
            failTask(captureTask);
            return;
        }
        const path = runtimeRoot + "/.mitishell-notification-"
            + captureTask.recordId + "-" + captureTask.role + ".png";
        media.grabToImage(function(result) {
            const completedCapture = root.captureTask;
            if (completedCapture === null || !result || !result.saveToFile(path)) {
                root.failTask(completedCapture);
                return;
            }
            root.importPayload = JSON.stringify({
                recordId: completedCapture.recordId,
                role: completedCapture.role,
                source: path,
                temporary: true,
            });
            root.importingTask = completedCapture;
            mediaImport.running = true;
        }, Qt.size(media.width, media.height));
    }

    onTaskChanged: {
        if (task === null || capturing) {
            return;
        }
        if (resolvedSource === "") {
            failTask(task);
        } else if (media.status === Image.Ready) {
            Qt.callLater(captureCurrent);
        }
    }

    Image {
        id: media

        anchors.fill: parent
        source: root.resolvedSource
        sourceSize.width: 256
        sourceSize.height: 256
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false

        onStatusChanged: {
            if (status === Image.Ready) {
                Qt.callLater(root.captureCurrent);
            } else if (status === Image.Error && root.task !== null) {
                root.failTask(root.task);
            }
        }
    }

    Process {
        id: mediaImport

        command: [Config.binary, "_notification-history-import"]
        stdinEnabled: true
        stdout: StdioCollector {
            id: mediaImportOutput
            waitForEnd: true
        }
        onStarted: write(root.importPayload)
        onExited: function(exitCode, exitStatus) {
            const completedTask = root.importingTask;
            root.importingTask = null;
            root.capturing = false;
            root.captureTask = null;
            if (completedTask === null) {
                Qt.callLater(root.captureCurrent);
                return;
            }
            Notifications.completeMediaCapture(
                completedTask.recordId,
                completedTask.role,
                exitCode === 0 ? mediaImportOutput.text.trim() : "",
            );
            Qt.callLater(root.captureCurrent);
        }
    }
}
