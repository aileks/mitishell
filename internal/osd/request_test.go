package osd_test

import (
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/osd"
)

func TestRequestRequiresVisibleContent(t *testing.T) {
	if _, err := osd.NewRequest("", "", nil, osd.DefaultDurationMS); err == nil {
		t.Fatal("NewRequest accepted an empty OSD")
	}
}

func TestRequestAcceptsMessageAndProgressTogether(t *testing.T) {
	progress := 42.5
	request, err := osd.NewRequest("volume", "Output", &progress, 1800.4)
	if err != nil {
		t.Fatal(err)
	}
	if request.Icon != "volume" ||
		request.Message != "Output" ||
		request.Progress == nil ||
		*request.Progress != 42.5 ||
		request.DurationMS != 1800 {
		t.Fatalf("request = %#v", request)
	}
}

func TestRequestRejectsInvalidProgressAndDuration(t *testing.T) {
	cases := []struct {
		name       string
		progress   float64
		durationMS float64
	}{
		{name: "negative progress", progress: -1, durationMS: 1200},
		{name: "high progress", progress: 101, durationMS: 1200},
		{name: "nan progress", progress: math.NaN(), durationMS: 1200},
		{name: "short duration", progress: 1, durationMS: 249},
		{name: "long duration", progress: 1, durationMS: 30001},
		{name: "infinite duration", progress: 1, durationMS: math.Inf(1)},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			if _, err := osd.NewRequest("", "message", &testCase.progress, testCase.durationMS); err == nil {
				t.Fatal("NewRequest accepted invalid input")
			}
		})
	}
}

func TestRequestNormalizesReadableLocalIcon(t *testing.T) {
	path := filepath.Join(t.TempDir(), "icon with space.png")
	if err := os.WriteFile(path, []byte("icon"), 0o600); err != nil {
		t.Fatal(err)
	}
	request, err := osd.NewRequest(path, "", nil, osd.DefaultDurationMS)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(request.Icon, "file://") || !strings.Contains(request.Icon, "icon%20with%20space.png") {
		t.Fatalf("icon = %q", request.Icon)
	}
}

func TestRequestRejectsRemoteAndUnreadableIcons(t *testing.T) {
	for _, icon := range []string{
		"https://example.com/icon.png",
		"file:///missing/mitishell-icon.png",
	} {
		if _, err := osd.NewRequest(icon, "", nil, osd.DefaultDurationMS); err == nil {
			t.Fatalf("NewRequest accepted %q", icon)
		}
	}
}
