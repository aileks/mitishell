package notifications_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/notifications"
)

func sampleState() notifications.State {
	return notifications.State{
		Version:    notifications.HistoryVersion,
		LastSeenAt: 125,
		Entries: []notifications.Entry{{
			RecordID:  "125-1",
			AppName:   "Mail",
			Summary:   "New message",
			Body:      "Hello",
			Urgency:   1,
			Timestamp: 125,
		}},
	}
}

func TestPathUsesXDGStateHome(t *testing.T) {
	stateRoot := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateRoot)
	path, err := notifications.Path()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(stateRoot, "mitishell", "notifications", "history.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestPathFallsBackToLocalState(t *testing.T) {
	homeDirectory := t.TempDir()
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", homeDirectory)
	path, err := notifications.Path()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(homeDirectory, ".local", "state", "mitishell", "notifications", "history.json")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestHistoryRoundTripIsPrivate(t *testing.T) {
	path := filepath.Join(t.TempDir(), "notifications", "history.json")
	history := notifications.NewFileHistory(path)
	if err := history.Save(sampleState()); err != nil {
		t.Fatal(err)
	}
	loaded, err := history.Load()
	if err != nil {
		t.Fatal(err)
	}
	if loaded.LastSeenAt != 125 || len(loaded.Entries) != 1 || loaded.Entries[0].Summary != "New message" {
		t.Fatalf("loaded = %#v", loaded)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o", info.Mode().Perm())
	}
	directoryInfo, err := os.Stat(filepath.Dir(path))
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0o700 {
		t.Fatalf("directory mode = %o", directoryInfo.Mode().Perm())
	}
}

func TestMissingHistoryStartsEmpty(t *testing.T) {
	loaded, err := notifications.NewFileHistory(filepath.Join(t.TempDir(), "history.json")).Load()
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Version != 1 || len(loaded.Entries) != 0 {
		t.Fatalf("loaded = %#v", loaded)
	}
}

func TestMalformedHistoryIsPreserved(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	contents := []byte(`{"version":1,"entries":[{"recordId":"bad id"}]}`)
	if err := os.WriteFile(path, contents, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := notifications.NewFileHistory(path).Load(); err == nil {
		t.Fatal("Load accepted malformed history")
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(contents) {
		t.Fatalf("history changed to %q", got)
	}
}

func TestUnknownSchemaFieldIsRejected(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	if err := os.WriteFile(path, []byte(`{"version":1,"lastSeenAt":0,"entries":[],"extra":true}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := notifications.NewFileHistory(path).Load(); err == nil {
		t.Fatal("Load accepted an unknown state field")
	}
}

func TestInvalidSaveDoesNotReplaceExistingHistory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	history := notifications.NewFileHistory(path)
	if err := history.Save(sampleState()); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	invalid := sampleState()
	invalid.Entries[0].RecordID = "unsafe id"
	if err := history.Save(invalid); err == nil {
		t.Fatal("Save accepted an unsafe record id")
	}
	after, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(after) != string(before) {
		t.Fatal("invalid save replaced existing history")
	}
}

func TestSaveTrimsHistoryToLimit(t *testing.T) {
	state := notifications.EmptyState()
	for index := 0; index < notifications.HistoryLimit+3; index++ {
		state.Entries = append(state.Entries, notifications.Entry{
			RecordID:  "record-" + strings.Repeat("x", index+1),
			Urgency:   1,
			Timestamp: int64(index),
		})
	}
	history := notifications.NewFileHistory(filepath.Join(t.TempDir(), "history.json"))
	if err := history.Save(state); err != nil {
		t.Fatal(err)
	}
	loaded, err := history.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(loaded.Entries) != notifications.HistoryLimit {
		t.Fatalf("len(entries) = %d", len(loaded.Entries))
	}
}

func TestImportMediaCopiesAndClearRemovesIt(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "avatar.png")
	if err := os.WriteFile(source, []byte("image"), 0o644); err != nil {
		t.Fatal(err)
	}
	history := notifications.NewFileHistory(filepath.Join(root, "state", "history.json"))
	url, err := history.ImportMedia(notifications.MediaImport{
		RecordID: "125-1",
		Role:     "appIcon",
		Source:   source,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(url, "file://") {
		t.Fatalf("url = %q", url)
	}
	mediaPath := strings.TrimPrefix(url, "file://")
	info, err := os.Stat(mediaPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o", info.Mode().Perm())
	}
	mediaDirectoryInfo, err := os.Stat(filepath.Dir(mediaPath))
	if err != nil {
		t.Fatal(err)
	}
	if mediaDirectoryInfo.Mode().Perm() != 0o700 {
		t.Fatalf("media directory mode = %o", mediaDirectoryInfo.Mode().Perm())
	}
	if err := history.Clear(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(mediaPath); !os.IsNotExist(err) {
		t.Fatalf("media remains: %v", err)
	}
}

func TestSaveRemovesOrphanedMedia(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "preview.png")
	if err := os.WriteFile(source, []byte("image"), 0o600); err != nil {
		t.Fatal(err)
	}
	history := notifications.NewFileHistory(filepath.Join(root, "state", "history.json"))
	mediaURL, err := history.ImportMedia(notifications.MediaImport{
		RecordID: "125-1",
		Role:     "image",
		Source:   source,
	})
	if err != nil {
		t.Fatal(err)
	}
	state := sampleState()
	state.Entries[0].Image = mediaURL
	if err := history.Save(state); err != nil {
		t.Fatal(err)
	}
	state.Entries = nil
	if err := history.Save(state); err != nil {
		t.Fatal(err)
	}
	mediaPath := strings.TrimPrefix(mediaURL, "file://")
	if _, err := os.Stat(mediaPath); !os.IsNotExist(err) {
		t.Fatalf("orphaned media remains: %v", err)
	}
}

func TestTemporaryMediaSourceIsRemovedAfterImport(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "capture.png")
	if err := os.WriteFile(source, []byte("image"), 0o600); err != nil {
		t.Fatal(err)
	}
	history := notifications.NewFileHistory(filepath.Join(root, "state", "history.json"))
	if _, err := history.ImportMedia(notifications.MediaImport{
		RecordID:  "125-1",
		Role:      "image",
		Source:    source,
		Temporary: true,
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(source); !os.IsNotExist(err) {
		t.Fatalf("temporary source remains: %v", err)
	}
}
