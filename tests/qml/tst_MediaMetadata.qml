pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../shell/components"

Item {
    width: 320
    height: 80

    MediaMetadata {
        id: metadata

        title: "A deliberately long media title"
        artist: "A deliberately long artist name"
        horizontalPadding: 8
        animationsEnabled: false
    }

    TestCase {
        name: "MediaMetadata"
        when: windowShown

        function test_intrinsic_width_keeps_eight_pixel_insets() {
            metadata.width = metadata.implicitWidth;
            compare(metadata.viewport.x, 8);
            compare(metadata.viewport.width, metadata.width - 16);
        }

        function test_capped_width_keeps_eight_pixel_insets() {
            metadata.width = 176;
            compare(metadata.viewport.x, 8);
            compare(metadata.viewport.width, 160);
        }
    }
}
