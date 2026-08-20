package ipc_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/aileks/mitishell/internal/ipc"
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
	client := ipc.NewClient(fakeQS(t, "notifications toggled"), "/tmp/mitishell-shell")
	if err := client.ToggleNotifications(); err != nil {
		t.Fatalf("ToggleNotifications() error = %v", err)
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
