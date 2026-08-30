package clipboard_test

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/clipboard"
)

func TestRecordAddsTextFirstAndDeduplicates(t *testing.T) {
	history := clipboard.History{Entries: []string{"first", "second", "third"}}
	recorded := clipboard.Record(history, "second", 25)
	if len(recorded.Entries) != 3 || recorded.Entries[0] != "second" {
		t.Fatalf("entries = %#v", recorded.Entries)
	}
	if recorded.Entries[1] != "first" || recorded.Entries[2] != "third" {
		t.Fatalf("order lost: %#v", recorded.Entries)
	}
	fresh := clipboard.Record(history, "new text", 25)
	if len(fresh.Entries) != 4 || fresh.Entries[0] != "new text" {
		t.Fatalf("entries = %#v", fresh.Entries)
	}
}

func TestRecordSkipsBlankInvalidOrOversizeText(t *testing.T) {
	history := clipboard.History{Entries: []string{"kept"}}
	oversize := strings.Repeat("a", clipboard.MaxEntryRunes+1)
	if kept := clipboard.Record(history, "   ", 25); len(kept.Entries) != 1 {
		t.Fatalf("blank recorded: %#v", kept.Entries)
	}
	if kept := clipboard.Record(history, "", 25); len(kept.Entries) != 1 {
		t.Fatalf("empty recorded: %#v", kept.Entries)
	}
	if kept := clipboard.Record(history, oversize, 25); len(kept.Entries) != 1 {
		t.Fatalf("oversize recorded: %#v", kept.Entries)
	}
	if kept := clipboard.Record(history, "\nline\n", 25); len(kept.Entries) != 2 {
		t.Fatalf("multiline not recorded: %#v", kept.Entries)
	}
}

func TestRecordCapsEntries(t *testing.T) {
	history := clipboard.History{}
	for index := 0; index < 5; index++ {
		history = clipboard.Record(history, fmt.Sprintf("entry-%d", index), 4)
	}
	if len(history.Entries) != 4 {
		t.Fatalf("entries = %#v", history.Entries)
	}
	if history.Entries[0] != "entry-4" {
		t.Fatalf("newest missing: %#v", history.Entries)
	}
}

func TestHistoryPathUsesStateHome(t *testing.T) {
	stateRoot := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateRoot)
	path, err := clipboard.HistoryPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(stateRoot, "mitishell", "clipboard-history.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestHistoryPathFallsBackToLocalState(t *testing.T) {
	homeDirectory := t.TempDir()
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", homeDirectory)
	path, err := clipboard.HistoryPath()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(homeDirectory, ".local", "state", "mitishell", "clipboard-history.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestMissingHistoryLoadsAsEmpty(t *testing.T) {
	store := clipboard.NewFileHistory(filepath.Join(t.TempDir(), "history.json"))
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.Version != clipboard.HistoryVersion || len(state.Entries) != 0 {
		t.Fatalf("state = %#v", state)
	}
}

func TestHistorySaveDeduplicatesAndLimitsEntries(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "clipboard-history.json")
	store := clipboard.NewFileHistory(path)
	entries := []string{"first", "first"}
	for index := 0; index < clipboard.HistoryLimit+10; index++ {
		entries = append(entries, "entry "+strings.Repeat("x", index))
	}
	if err := store.Save(clipboard.History{Entries: entries}); err != nil {
		t.Fatal(err)
	}
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Entries) != clipboard.HistoryLimit {
		t.Fatalf("entries = %d, want %d", len(state.Entries), clipboard.HistoryLimit)
	}
	if state.Entries[0] != "first" {
		t.Fatalf("first entry = %q, want %q", state.Entries[0], "first")
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("permissions = %o", info.Mode().Perm())
	}
}

func TestHistoryPreservesMultilineEntries(t *testing.T) {
	store := clipboard.NewFileHistory(filepath.Join(t.TempDir(), "history.json"))
	entry := "line one\nline two\ttabbed"
	if err := store.Save(clipboard.History{Entries: []string{entry}}); err != nil {
		t.Fatal(err)
	}
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Entries) != 1 || state.Entries[0] != entry {
		t.Fatalf("entries = %#v", state.Entries)
	}
}

func TestHistoryRejectsOversizeEntries(t *testing.T) {
	store := clipboard.NewFileHistory(filepath.Join(t.TempDir(), "history.json"))
	oversize := strings.Repeat("a", clipboard.MaxEntryRunes+1)
	if err := store.Save(clipboard.History{Entries: []string{oversize}}); err == nil {
		t.Fatal("Save accepted an oversize entry")
	}
}

func TestHistoryRejectMalformedState(t *testing.T) {
	oversize := strings.Repeat("a", clipboard.MaxEntryRunes+1)
	for name, contents := range map[string]string{
		"unknown field": `{"version":1,"entries":[],"extra":true}`,
		"bad version":   `{"version":2,"entries":[]}`,
		"duplicate":     `{"version":1,"entries":["a","a"]}`,
		"blank":         `{"version":1,"entries":["  "]}`,
		"oversize":      `{"version":1,"entries":["` + oversize + `"]}`,
		"trailing":      `{"version":1,"entries":[]} {}`,
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "history.json")
			if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := clipboard.NewFileHistory(path).Load(); err == nil {
				t.Fatal("Load accepted malformed history")
			}
		})
	}
}

func TestHistoryClearIsIdempotent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "clipboard-history.json")
	store := clipboard.NewFileHistory(path)
	if err := store.Save(clipboard.History{Entries: []string{"text"}}); err != nil {
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

func TestHistoryWritesVersionedJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "clipboard-history.json")
	store := clipboard.NewFileHistory(path)
	if err := store.Save(clipboard.History{Entries: []string{"text"}}); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var state clipboard.History
	if err := json.Unmarshal(contents, &state); err != nil {
		t.Fatal(err)
	}
	if state.Version != 1 || len(state.Entries) != 1 || state.Entries[0] != "text" {
		t.Fatalf("state = %#v", state)
	}
}
