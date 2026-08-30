package launcher_test

import (
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/aileks/mitishell/internal/launcher"
)

func TestRecentsPathUsesXDGStateHome(t *testing.T) {
	stateRoot := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateRoot)

	path, err := launcher.RecentsPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(stateRoot, "mitishell", "launcher-recents.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestRecentsPathFallsBackToLocalState(t *testing.T) {
	homeDirectory := t.TempDir()
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", homeDirectory)

	path, err := launcher.RecentsPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(homeDirectory, ".local", "state", "mitishell", "launcher-recents.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestMissingRecentsAreEmpty(t *testing.T) {
	state, err := launcher.NewFileRecents(filepath.Join(t.TempDir(), "missing.json")).Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.Version != launcher.RecentsVersion || len(state.Entries) != 0 {
		t.Fatalf("state = %#v", state)
	}
}

func TestRecentsRoundTripNormalizesAndSecuresState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "private", "launcher-recents.json")
	store := launcher.NewFileRecents(path)
	input := launcher.Recents{Entries: []string{
		"firefox.desktop", "org.gnome.Nautilus.desktop", "firefox.desktop",
		"foot.desktop", "signal.desktop", "spotify.desktop", "ignored.desktop",
	}}
	if err := store.Save(input); err != nil {
		t.Fatal(err)
	}

	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"firefox.desktop", "org.gnome.Nautilus.desktop", "foot.desktop",
		"signal.desktop", "spotify.desktop",
	}
	if state.Version != launcher.RecentsVersion || !slices.Equal(state.Entries, want) {
		t.Fatalf("state = %#v", state)
	}

	directoryInfo, err := os.Stat(filepath.Dir(path))
	if err != nil {
		t.Fatal(err)
	}
	fileInfo, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0o700 || fileInfo.Mode().Perm() != 0o600 {
		t.Fatalf("directory mode=%o file mode=%o", directoryInfo.Mode().Perm(), fileInfo.Mode().Perm())
	}
}

func TestRecentsRejectInvalidFiles(t *testing.T) {
	for name, contents := range map[string]string{
		"version":   `{"version":2,"entries":[]}`,
		"unknown":   `{"version":1,"entries":[],"extra":true}`,
		"duplicate": `{"version":1,"entries":["app.desktop","app.desktop"]}`,
		"empty":     `{"version":1,"entries":[""]}`,
		"control":   "{\"version\":1,\"entries\":[\"bad\\n.desktop\"]}",
		"trailing":  `{"version":1,"entries":[]} {}`,
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "launcher-recents.json")
			if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
				t.Fatal(err)
			}
			_, err := launcher.NewFileRecents(path).Load()
			if err == nil {
				t.Fatalf("error = %v", err)
			}
		})
	}
}
