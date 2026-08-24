package emoji_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/aileks/mitishell/internal/emoji"
)

func TestRecentsPathUsesStateHome(t *testing.T) {
	stateRoot := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateRoot)
	path, err := emoji.RecentsPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(stateRoot, "mitishell", "emoji-recents.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestRecentsPathFallsBackToLocalState(t *testing.T) {
	homeDirectory := t.TempDir()
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", homeDirectory)
	path, err := emoji.RecentsPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(homeDirectory, ".local", "state", "mitishell", "emoji-recents.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestMissingRecentsLoadAsEmpty(t *testing.T) {
	store := emoji.NewFileRecents(filepath.Join(t.TempDir(), "recents.json"))
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.Version != emoji.RecentsVersion || len(state.Entries) != 0 {
		t.Fatalf("state = %#v", state)
	}
}

func TestRecentsSaveDeduplicatesAndLimitsEntries(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "emoji-recents.json")
	store := emoji.NewFileRecents(path)
	entries := []string{"😀", "😀"}
	for index := 0; index < 30; index++ {
		entries = append(entries, string(rune(0x1F601+index)))
	}
	if err := store.Save(emoji.Recents{Entries: entries}); err != nil {
		t.Fatal(err)
	}
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Entries) != emoji.RecentsLimit || state.Entries[0] != "😀" || state.Entries[1] != "😁" {
		t.Fatalf("entries = %#v", state.Entries)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("permissions = %o", info.Mode().Perm())
	}
}

func TestRecentsRejectMalformedState(t *testing.T) {
	for name, contents := range map[string]string{
		"unknown field": `{"version":1,"entries":[],"extra":true}`,
		"bad version":   `{"version":2,"entries":[]}`,
		"duplicate":     `{"version":1,"entries":["😀","😀"]}`,
		"control":       `{"version":1,"entries":["😀\n"]}`,
		"trailing":      `{"version":1,"entries":[]} {}`,
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "recents.json")
			if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := emoji.NewFileRecents(path).Load(); err == nil {
				t.Fatal("Load accepted malformed recents")
			}
		})
	}
}

func TestRecentsClearIsIdempotent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "emoji-recents.json")
	store := emoji.NewFileRecents(path)
	if err := store.Save(emoji.Recents{Entries: []string{"😀"}}); err != nil {
		t.Fatal(err)
	}
	if err := store.Clear(); err != nil {
		t.Fatal(err)
	}
	if err := store.Clear(); err != nil {
		t.Fatal(err)
	}
	state, err := store.Load()
	if err != nil || len(state.Entries) != 0 {
		t.Fatalf("state=%#v err=%v", state, err)
	}
}

func TestRecentsWritesVersionedJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "emoji-recents.json")
	store := emoji.NewFileRecents(path)
	if err := store.Save(emoji.Recents{Entries: []string{"🎉"}}); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var state emoji.Recents
	if err := json.Unmarshal(contents, &state); err != nil {
		t.Fatal(err)
	}
	if state.Version != 1 || len(state.Entries) != 1 || state.Entries[0] != "🎉" {
		t.Fatalf("state = %#v", state)
	}
}
