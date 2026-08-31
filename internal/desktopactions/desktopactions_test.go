package desktopactions_test

import (
	"context"
	"errors"
	"slices"
	"testing"

	"github.com/aileks/mitishell/internal/desktopactions"
)

type runnerStub struct {
	paths   map[string]string
	outputs map[string]string
	errors  map[string]error
}

func (stub runnerStub) LookPath(file string) (string, error) {
	if path := stub.paths[file]; path != "" {
		return path, nil
	}
	return "", errors.New("not found")
}

func (stub runnerStub) Output(_ context.Context, name string, args ...string) (string, error) {
	key := name
	if len(args) > 0 {
		key += " " + args[0]
	}
	return stub.outputs[key], stub.errors[key]
}

func TestSnapshotDiscoversNativeActions(t *testing.T) {
	t.Setenv("TERMINAL", "")
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	service := desktopactions.NewService(runnerStub{
		paths: map[string]string{
			"grim":                "/usr/bin/grim",
			"wl-copy":             "/usr/bin/wl-copy",
			"notify-send":         "/usr/bin/notify-send",
			"hyprctl":             "/usr/bin/hyprctl",
			"slurp":               "/usr/bin/slurp",
			"hyprpicker":          "/usr/bin/hyprpicker",
			"tesseract":           "/usr/bin/tesseract",
			"zbarimg":             "/usr/bin/zbarimg",
			"gpu-screen-recorder": "/usr/bin/gpu-screen-recorder",
			"powerprofilesctl":    "/usr/bin/powerprofilesctl",
			"fwupdmgr":            "/usr/bin/fwupdmgr",
			"bash":                "/usr/bin/bash",
			"foot":                "/usr/bin/foot",
		},
		outputs: map[string]string{
			"/usr/bin/powerprofilesctl get":  "balanced\n",
			"/usr/bin/powerprofilesctl list": "  power-saver:\n* balanced:\n  performance:\n",
		},
	})

	result := service.Snapshot(context.Background())
	if result.RecordingActive || len(result.PowerProfiles) != 3 || !result.PowerProfiles[1].Active {
		t.Fatalf("result = %#v", result)
	}
	if !slices.Equal(result.ScreenshotModes, []string{"region", "window", "output", "desktop"}) ||
		!slices.Equal(result.RecordingModes, []string{"region", "output"}) ||
		!result.OCRAvailable || !result.QRAvailable || !result.FirmwareAvailable {
		t.Fatalf("result = %#v", result)
	}
}

func TestSnapshotHidesUnavailableAndFailedProviders(t *testing.T) {
	t.Setenv("TERMINAL", "")
	service := desktopactions.NewService(runnerStub{
		paths: map[string]string{"powerprofilesctl": "/usr/bin/powerprofilesctl"},
		errors: map[string]error{
			"/usr/bin/powerprofilesctl get": errors.New("unavailable"),
		},
	})
	result := service.Snapshot(context.Background())
	if len(result.ScreenshotModes) != 0 || len(result.RecordingModes) != 0 ||
		len(result.PowerProfiles) != 0 || result.FirmwareAvailable {
		t.Fatalf("result = %#v", result)
	}
}

func TestRecordingActionsUseRecorderAndCaptureToolsInsteadOfHelperScripts(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	service := desktopactions.NewService(runnerStub{
		paths: map[string]string{
			"gpu-screen-recorder": "/usr/bin/gpu-screen-recorder",
			"notify-send":         "/usr/bin/notify-send",
			"slurp":               "/usr/bin/slurp",
		},
	})
	result := service.Snapshot(context.Background())
	if result.RecordingActive || !slices.Equal(result.RecordingModes, []string{"region"}) {
		t.Fatalf("result = %#v", result)
	}
}

func TestRunReportsMissingPackagesClearly(t *testing.T) {
	service := desktopactions.NewService(runnerStub{paths: map[string]string{}})
	for _, testCase := range []struct {
		args []string
		want string
	}{
		{args: []string{"screenshot", "desktop"}, want: "Please install grim for screenshots"},
		{args: []string{"record", "output", "none"}, want: "Please install gpu-screen-recorder for screen recording"},
		{args: []string{"qr"}, want: "Please install grim for QR scanning"},
	} {
		err := service.Run(context.Background(), testCase.args)
		if err == nil || err.Error() != testCase.want {
			t.Fatalf("Run(%#v) error = %v, want %q", testCase.args, err, testCase.want)
		}
	}
}
