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

func TestSnapshotDiscoversCommandsAndLiveState(t *testing.T) {
	t.Setenv("TERMINAL", "")
	service := desktopactions.NewService(runnerStub{
		paths: map[string]string{
			"desktop-screenshot": "/home/test/.local/bin/desktop-screenshot",
			"desktop-record":     "/home/test/.local/bin/desktop-record",
			"powerprofilesctl":   "/usr/bin/powerprofilesctl",
			"fwupdmgr":           "/usr/bin/fwupdmgr",
			"bash":               "/usr/bin/bash",
			"foot":               "/usr/bin/foot",
		},
		outputs: map[string]string{
			"/home/test/.local/bin/desktop-record status": "/tmp/recording.mp4\n",
			"/usr/bin/powerprofilesctl get":               "balanced\n",
			"/usr/bin/powerprofilesctl list":              "  power-saver:\n* balanced:\n  performance:\n",
		},
	})

	result := service.Snapshot(context.Background())
	if !result.RecordingActive || len(result.PowerProfiles) != 3 || !result.PowerProfiles[1].Active {
		t.Fatalf("result = %#v", result)
	}
	if !slices.Equal(result.FirmwareCommand, []string{
		"/usr/bin/foot", "/usr/bin/bash", "-lc", "fwupdmgr refresh && fwupdmgr update",
	}) {
		t.Fatalf("firmware command = %#v", result.FirmwareCommand)
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
	if len(result.ScreenshotCommand) != 0 || len(result.PowerProfiles) != 0 || len(result.FirmwareCommand) != 0 {
		t.Fatalf("result = %#v", result)
	}
}

func TestInactiveRecordingKeepsRecordActionsAvailable(t *testing.T) {
	service := desktopactions.NewService(runnerStub{
		paths: map[string]string{"desktop-record": "/usr/bin/desktop-record"},
		errors: map[string]error{
			"/usr/bin/desktop-record status": errors.New("not recording"),
		},
	})
	result := service.Snapshot(context.Background())
	if result.RecordingActive || len(result.RecordingCommand) == 0 {
		t.Fatalf("result = %#v", result)
	}
}
