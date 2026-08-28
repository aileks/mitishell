pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../shell/components"

Item {
    width: 240
    height: 80

    OverflowRow {
        id: overflowRow

        width: 80
        height: 30
        animationsEnabled: false
        reducedMotion: false
        fallback: Text {
            objectName: "staticMetadata"
            width: overflowRow.width
            text: "A deliberately long static label"
            elide: Text.ElideRight
        }

        Rectangle {
            id: contentFixture
            objectName: "contentFixture"

            width: 240
            height: 20
        }
    }

    TestCase {
        name: "OverflowRow"
        when: windowShown

        function init() {
            overflowRow.animationsEnabled = false;
            overflowRow.reducedMotion = false;
            contentFixture.width = 240;
        }

        function test_overflow_elides_when_animations_are_disabled() {
            const staticMetadata = findChild(overflowRow, "staticMetadata");
            verify(staticMetadata !== null);
            verify(staticMetadata.visible);
            compare(staticMetadata.elide, Text.ElideRight);
        }

        function test_overflow_elides_for_reduced_motion() {
            overflowRow.animationsEnabled = true;
            overflowRow.reducedMotion = true;

            const staticMetadata = findChild(overflowRow, "staticMetadata");
            verify(staticMetadata !== null);
            verify(staticMetadata.visible);
            compare(staticMetadata.elide, Text.ElideRight);
        }

        function test_overflow_marquee_runs_with_normal_motion() {
            overflowRow.animationsEnabled = true;
            overflowRow.reducedMotion = false;

            const marquee = findChild(overflowRow, "overflowMarquee");
            verify(marquee !== null);
            tryCompare(marquee, "running", true);
        }

        function test_content_width_change_restarts_marquee() {
            overflowRow.animationsEnabled = true;
            overflowRow.reducedMotion = false;

            const marquee = findChild(overflowRow, "overflowMarquee");
            tryCompare(marquee, "running", true);
            marquee.stop();
            compare(marquee.running, false);

            contentFixture.width = 260;
            tryCompare(marquee, "running", true);
        }

        function test_short_content_needs_no_fallback_or_marquee() {
            contentFixture.width = 40;

            tryCompare(overflowRow, "overflow", false);
            compare(overflowRow.fallbackNeeded, false);
            const marquee = findChild(overflowRow, "overflowMarquee");
            compare(marquee.running, false);
        }
    }
}
