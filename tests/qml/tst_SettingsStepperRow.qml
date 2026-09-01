pragma ComponentBehavior: Bound

import QtQuick
import QtTest
Item {
    id: fixture

    width: 320
    height: 120

    Loader {
        id: stepperLoader
    }

    SignalSpy {
        id: queuedSpy
        target: stepperLoader.item
        signalName: "valueQueued"
    }

    TestCase {
        name: "IntegerStepper"
        when: windowShown

        function initTestCase() {
            stepperLoader.setSource(
                Qt.resolvedUrl("../../shell/components/IntegerStepper.qml"),
                {
                    width: 320,
                    label: "Standard size",
                    value: 14,
                    from: 10,
                    to: 20,
                    controlHeight: 36,
                    spacing: 4,
                    labelFontFamily: "sans-serif",
                    labelFontSize: 14,
                    valueFontFamily: "monospace",
                    valueFontSize: 14,
                    buttonFontFamily: "monospace",
                    buttonFontSize: 16,
                    textColor: "white",
                    valueColor: "white",
                    pendingColor: "yellow",
                    buttonColor: "black",
                    hoverColor: "gray",
                    pressedColor: "darkgray",
                    borderColor: "gray",
                    focusColor: "blue",
                },
            );
            tryCompare(stepperLoader, "status", Loader.Ready);
        }

        function init() {
            const stepper = stepperLoader.item;
            stepper.value = 14;
            stepper.pending = false;
            stepper.draftValue = 14;
            queuedSpy.clear();
        }

        function test_repeated_steps_queue_the_latest_local_value() {
            const stepper = stepperLoader.item;
            stepper.increment();
            stepper.increment();

            compare(stepper.draftValue, 16);
            compare(stepper.pending, true);
            compare(queuedSpy.count, 2);
            compare(queuedSpy.signalArguments[1][0], 16);
        }

        function test_steps_stop_at_both_bounds() {
            const stepper = stepperLoader.item;
            stepper.draftValue = 10;
            stepper.decrement();
            compare(stepper.draftValue, 10);
            compare(stepper.canDecrement, false);

            stepper.draftValue = 20;
            stepper.increment();
            compare(stepper.draftValue, 20);
            compare(stepper.canIncrement, false);
        }

        function test_matching_failure_restores_the_stored_value() {
            const stepper = stepperLoader.item;
            stepper.increment();
            stepper.markFailed(15);

            compare(stepper.draftValue, 14);
            compare(stepper.pending, false);
        }

        function test_matching_success_finishes_the_pending_step() {
            const stepper = stepperLoader.item;
            stepper.increment();
            stepper.markSaved(15);

            compare(stepper.draftValue, 15);
            compare(stepper.pending, false);
        }

        function test_external_value_sync_waits_for_pending_work() {
            const stepper = stepperLoader.item;
            stepper.value = 13;
            compare(stepper.draftValue, 13);

            stepper.increment();
            stepper.value = 12;
            compare(stepper.draftValue, 14);
        }

        function test_newer_pending_value_survives_an_older_completion() {
            const stepper = stepperLoader.item;
            stepper.increment();
            stepper.increment();
            stepper.markSaved(15);

            compare(stepper.draftValue, 16);
            compare(stepper.pending, true);
        }

        function test_keyboard_activates_the_focused_button() {
            const stepper = stepperLoader.item;
            const incrementButton = findChild(stepper, "incrementButton");
            verify(incrementButton !== null);
            incrementButton.forceActiveFocus();
            keyClick(Qt.Key_Return);

            compare(stepper.draftValue, 15);
            compare(queuedSpy.signalArguments[0][0], 15);
        }
    }
}
