package ipc_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/aileks/mitishell/internal/ipc"
	"github.com/aileks/mitishell/internal/osd"
)

func TestPingAcceptsOnlyMitishellPong(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "pong"), "/tmp/mitishell-shell")
	if err := client.Ping(); err != nil {
		t.Fatalf("Ping() error = %v", err)
	}
}

func TestPingRejectsUnexpectedInstanceResponse(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "other-shell"), "/tmp/mitishell-shell")
	if err := client.Ping(); err == nil {
		t.Fatal("Ping() accepted an unexpected response")
	}
}

func TestReloadAcceptsAcknowledgement(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "reload requested"), "/tmp/mitishell-shell")
	if err := client.Reload(); err != nil {
		t.Fatalf("Reload() error = %v", err)
	}
}

func TestToggleNotificationsAcceptsAcknowledgement(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "do not disturb toggled"), "/tmp/mitishell-shell")
	if err := client.ToggleNotifications(); err != nil {
		t.Fatalf("ToggleNotifications() error = %v", err)
	}
}

func TestShowOSDPassesEveryFieldPositionally(t *testing.T) {
	client := ipc.NewClient(fakeQSCheckingOSD(t), "/tmp/mitishell-shell")
	progress := 37.5
	err := client.ShowOSD(osd.Request{
		Icon:       "reminder",
		Message:    "Tea ready",
		Progress:   &progress,
		DurationMS: 2400,
	})
	if err != nil {
		t.Fatalf("ShowOSD() error = %v", err)
	}
}

func TestOpenPowerMenuRejectsUnexpectedResponse(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "unavailable"), "/tmp/mitishell-shell")
	if err := client.OpenPowerMenu(); err == nil {
		t.Fatal("OpenPowerMenu() accepted an unexpected response")
	}
}

func fakeQS(t *testing.T, response string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "qs")
	contents := "#!/bin/sh\nprintf '%s\\n' '" + response + "'\n"
	if err := os.WriteFile(path, []byte(contents), 0o700); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestVolumeActionPassesArgumentPositionally(t *testing.T) {
	client := ipc.NewClient(fakeQSCheckingArg(t, "up", "volume updated"), "/tmp/mitishell-shell")
	if err := client.Volume("up"); err != nil {
		t.Fatalf("Volume() error = %v", err)
	}
}

func TestVolumeActionRejectsUnexpectedResponse(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "volume unavailable"), "/tmp/mitishell-shell")
	if err := client.Volume("up"); err == nil {
		t.Fatal("Volume() accepted an unexpected response")
	}
}

func TestVolumeSetPassesValuePositionally(t *testing.T) {
	client := ipc.NewClient(fakeQSCheckingArg(t, "80", "volume updated"), "/tmp/mitishell-shell")
	if err := client.VolumeSet(80); err != nil {
		t.Fatalf("VolumeSet() error = %v", err)
	}
}

func TestMicActionAcceptsAcknowledgement(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "microphone updated"), "/tmp/mitishell-shell")
	if err := client.Mic("mute"); err != nil {
		t.Fatalf("Mic() error = %v", err)
	}
}

func TestBrightnessActionAcceptsAcknowledgement(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "brightness updated"), "/tmp/mitishell-shell")
	if err := client.Brightness("down"); err != nil {
		t.Fatalf("Brightness() error = %v", err)
	}
}

func TestBrightnessSetRejectsUnexpectedResponse(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "brightness unavailable"), "/tmp/mitishell-shell")
	if err := client.BrightnessSet(50); err == nil {
		t.Fatal("BrightnessSet() accepted an unexpected response")
	}
}

// fakeQSCheckingArg answers with the acknowledgement only when the final
// positional argument of the call matches, so tests exercise argument
// passing rather than a canned reply.
func fakeQSCheckingArg(t *testing.T, argument string, response string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "qs")
	contents := "#!/bin/sh\n[ \"$8\" = '" + argument + "' ] && printf '%s\\n' '" + response + "' || printf 'wrong argument %s\\n' \"$8\"\n"
	if err := os.WriteFile(path, []byte(contents), 0o700); err != nil {
		t.Fatal(err)
	}
	return path
}

func fakeQSCheckingOSD(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "qs")
	contents := `#!/bin/sh
if [ "$8" = 'reminder' ] && [ "$9" = 'Tea ready' ] && [ "${10}" = '37.5' ] && [ "${11}" = '2400' ]; then
    printf '%s\n' 'OSD shown'
else
    printf '%s\n' 'wrong OSD arguments'
fi
`
	if err := os.WriteFile(path, []byte(contents), 0o700); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestToggleControlCenterPassesPagePositionally(t *testing.T) {
	client := ipc.NewClient(fakeQSCheckingArg(t, "audio", "control center toggled"), "/tmp/mitishell-shell")
	if err := client.ToggleControlCenter("audio"); err != nil {
		t.Fatalf("ToggleControlCenter() error = %v", err)
	}
}

func TestToggleControlCenterRejectsUnexpectedResponse(t *testing.T) {
	client := ipc.NewClient(fakeQS(t, "control center unavailable"), "/tmp/mitishell-shell")
	if err := client.ToggleControlCenter("home"); err == nil {
		t.Fatal("ToggleControlCenter() accepted an unexpected response")
	}
}
