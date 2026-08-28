import QtQuick
import QtTest
import "../../shell/components"

Item {
    id: harness

    width: 200
    height: 80

    property int taps: 0
    property int dragStarts: 0
    property int dragMoves: 0
    property int dragFinishes: 0
    property int dragCancels: 0

    Rectangle {
        id: island

        width: 160
        height: 40

        TapHandler {
            onTapped: harness.taps += 1
        }

        BarReorderGesture {
            id: reorderGesture

            dragThreshold: 4
            onDragStarted: harness.dragStarts += 1
            onDragMoved: harness.dragMoves += 1
            onDragFinished: harness.dragFinishes += 1
            onDragCanceled: harness.dragCancels += 1
        }
    }

    TestCase {
        name: "BarReorderGesture"
        when: windowShown

        function init() {
            harness.taps = 0;
            harness.dragStarts = 0;
            harness.dragMoves = 0;
            harness.dragFinishes = 0;
            harness.dragCancels = 0;
            reorderGesture.enabled = true;
            reorderGesture.verticalEnabled = false;
        }

        function test_click_reaches_island_action() {
            mouseClick(island, 20, 20, Qt.LeftButton);
            compare(harness.taps, 1);
            compare(harness.dragStarts, 0);
            compare(harness.dragFinishes, 0);
        }

        function test_movement_below_threshold_does_not_drag() {
            mousePress(island, 20, 20, Qt.LeftButton);
            mouseMove(island, 23, 20, 10, Qt.LeftButton);
            mouseRelease(island, 23, 20, Qt.LeftButton);
            compare(harness.dragStarts, 0);
            compare(harness.dragFinishes, 0);
        }

        function test_direct_drag_owns_gesture_and_suppresses_click() {
            mousePress(island, 20, 20, Qt.LeftButton);
            mouseMove(island, 25, 20, 10, Qt.LeftButton);
            mouseMove(island, 40, 20, 10, Qt.LeftButton);
            mouseRelease(island, 40, 20, Qt.LeftButton);
            compare(harness.dragStarts, 1);
            verify(harness.dragMoves > 0);
            tryCompare(harness, "dragFinishes", 1);
            compare(harness.taps, 0);
        }

        function test_vertical_drag_can_reorder_settings_widget() {
            reorderGesture.verticalEnabled = true;
            mousePress(island, 20, 20, Qt.LeftButton);
            mouseMove(island, 20, 25, 10, Qt.LeftButton);
            mouseMove(island, 20, 40, 10, Qt.LeftButton);
            mouseRelease(island, 20, 40, Qt.LeftButton);
            compare(harness.dragStarts, 1);
            verify(harness.dragMoves > 0);
            tryCompare(harness, "dragFinishes", 1);
            compare(harness.taps, 0);
        }

        function test_cancellation_emits_no_drop() {
            mousePress(island, 20, 20, Qt.LeftButton);
            mouseMove(island, 25, 20, 10, Qt.LeftButton);
            compare(harness.dragStarts, 1);

            reorderGesture.enabled = false;
            mouseRelease(island, 25, 20, Qt.LeftButton);

            compare(harness.dragCancels, 1);
            compare(harness.dragFinishes, 0);
        }
    }
}
