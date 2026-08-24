package updates_test

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/updates"
)

type fakeRunner struct {
	paths   map[string]bool
	outputs map[string]string
	fail    map[string]error
}

func (fake fakeRunner) LookPath(file string) (string, error) {
	if fake.paths[file] {
		return "/usr/bin/" + file, nil
	}
	return "", errors.New("not found")
}

func (fake fakeRunner) Output(_ context.Context, name string, _ ...string) (string, error) {
	return fake.outputs[name], fake.fail[name]
}

func TestSnapshotCountsAndCapsPackageNames(t *testing.T) {
	lines := make([]string, 55)
	for index := range lines {
		lines[index] = fmt.Sprintf("package%d 1 -> 2", index)
	}
	result := updates.NewService(fakeRunner{
		paths:   map[string]bool{"checkupdates": true, "paru": true},
		outputs: map[string]string{"checkupdates": strings.Join(lines, "\n"), "paru": "mitishell 1 -> 2\n"},
	}).Snapshot(context.Background())
	if result.System.Count != 55 || len(result.System.Packages) != 50 || result.Aur.Count != 1 || result.Helper != "paru" {
		t.Fatalf("result = %#v", result)
	}
}

func TestSnapshotUnsupportedWithoutCheckupdates(t *testing.T) {
	result := updates.NewService(fakeRunner{paths: map[string]bool{"paru": true}}).Snapshot(context.Background())
	if result.Supported || result.Helper != "" {
		t.Fatalf("result = %#v", result)
	}
}

func TestSnapshotTreatsCheckupdatesExitTwoAsEmpty(t *testing.T) {
	result := updates.NewService(fakeRunner{
		paths: map[string]bool{"checkupdates": true},
		fail:  map[string]error{"checkupdates": updates.ErrNoUpdates},
	}).Snapshot(context.Background())
	if result.System.Count != 0 || result.System.Error != "" {
		t.Fatalf("system = %#v", result.System)
	}
}

func TestSnapshotPreservesSourceErrors(t *testing.T) {
	result := updates.NewService(fakeRunner{
		paths: map[string]bool{"checkupdates": true, "yay": true},
		fail:  map[string]error{"checkupdates": errors.New("database locked"), "yay": errors.New("network down")},
	}).Snapshot(context.Background())
	if !strings.Contains(result.System.Error, "database locked") || !strings.Contains(result.Aur.Error, "network down") || result.Helper != "yay" {
		t.Fatalf("result = %#v", result)
	}
}

func TestUpdateCommandPriorityAndTerminalForms(t *testing.T) {
	t.Setenv("TERMINAL", "")
	tests := []struct {
		name  string
		paths map[string]bool
		want  string
	}{
		{"xdg", map[string]bool{"checkupdates": true, "paru": true, "xdg-terminal-exec": true}, "/usr/bin/xdg-terminal-exec -- paru -Syu"},
		{"foot", map[string]bool{"checkupdates": true, "foot": true}, "/usr/bin/foot sudo pacman -Syu"},
		{"alacritty", map[string]bool{"checkupdates": true, "alacritty": true}, "/usr/bin/alacritty -e sudo pacman -Syu"},
		{"kitty", map[string]bool{"checkupdates": true, "kitty": true}, "/usr/bin/kitty sudo pacman -Syu"},
		{"ghostty", map[string]bool{"checkupdates": true, "ghostty": true}, "/usr/bin/ghostty -e sudo pacman -Syu"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := updates.NewService(fakeRunner{paths: test.paths}).Snapshot(context.Background())
			if got := strings.Join(result.UpdateCommand, " "); got != test.want {
				t.Fatalf("command = %q, want %q", got, test.want)
			}
		})
	}
}

func TestUpdateCommandUsesTerminalEnvironment(t *testing.T) {
	t.Setenv("TERMINAL", "alacritty --hold")
	result := updates.NewService(fakeRunner{paths: map[string]bool{"checkupdates": true}}).Snapshot(context.Background())
	if got, want := strings.Join(result.UpdateCommand, " "), "alacritty --hold -e sudo pacman -Syu"; got != want {
		t.Fatalf("command = %q, want %q", got, want)
	}
}

func TestUpdateCommandNilWithoutTerminal(t *testing.T) {
	t.Setenv("TERMINAL", "")
	result := updates.NewService(fakeRunner{paths: map[string]bool{"checkupdates": true}}).Snapshot(context.Background())
	if result.UpdateCommand != nil {
		t.Fatalf("command = %#v", result.UpdateCommand)
	}
}
