package clipboard_test

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/clipboard"
)

func TestRecordTextAddsFirstDeduplicatesAndCaps(t *testing.T) {
	history := clipboard.EmptyHistory()
	history = clipboard.RecordText(history, "first", 2)
	history = clipboard.RecordText(history, "second", 2)
	history = clipboard.RecordText(history, "first", 2)
	if len(history.Entries) != 2 || history.Entries[0].Text != "first" ||
		history.Entries[1].Text != "second" {
		t.Fatalf("entries = %#v", history.Entries)
	}
}

func TestRecordTextSkipsInvalidValues(t *testing.T) {
	history := clipboard.RecordText(clipboard.EmptyHistory(), "kept", 25)
	for _, value := range []string{"", "   ", strings.Repeat("a", clipboard.MaxEntryRunes+1)} {
		if got := clipboard.RecordText(history, value, 25); len(got.Entries) != 1 {
			t.Fatalf("value %q changed history: %#v", value, got)
		}
	}
}

func TestHistoryPathUsesStateHome(t *testing.T) {
	stateRoot := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateRoot)
	path, err := clipboard.HistoryPath()
	if err != nil {
		t.Fatal(err)
	}
	if want := filepath.Join(stateRoot, "mitishell", "clipboard-history.json"); path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}

func TestLegacyTextHistoryMigratesInMemory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	if err := os.WriteFile(path, []byte(`{"version":1,"entries":["first","second"]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	state, err := clipboard.NewFileHistory(path).Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.Version != clipboard.HistoryVersion || len(state.Entries) != 2 ||
		state.Entries[0].Kind != clipboard.KindText || state.Entries[0].Text != "first" {
		t.Fatalf("state = %#v", state)
	}
	contents, err := os.ReadFile(path)
	if err != nil || !bytes.Contains(contents, []byte(`"version":1`)) {
		t.Fatalf("legacy file was rewritten: %q err=%v", contents, err)
	}
}

func TestImageRecordPersistsMetadataAndCanBeReadBack(t *testing.T) {
	root := t.TempDir()
	store := clipboard.NewFileHistory(filepath.Join(root, "history.json"))
	imageBytes := testPNG(t, 3, 2)
	state, err := store.Record(clipboard.EmptyHistory(), imageBytes, 25)
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Entries) != 1 {
		t.Fatalf("state = %#v", state)
	}
	entry := state.Entries[0]
	if entry.Kind != clipboard.KindImage || entry.MimeType != "image/png" ||
		entry.Width != 3 || entry.Height != 2 || !strings.HasPrefix(entry.Image, "file://") {
		t.Fatalf("entry = %#v", entry)
	}
	if err := store.Save(state); err != nil {
		t.Fatal(err)
	}
	loadedEntry, loadedBytes, err := store.ImageData(entry.ID)
	if err != nil || loadedEntry.ID != entry.ID || !bytes.Equal(loadedBytes, imageBytes) {
		t.Fatalf("entry=%#v bytes=%d err=%v", loadedEntry, len(loadedBytes), err)
	}
	mediaPath := strings.TrimPrefix(entry.Image, "file://")
	info, err := os.Stat(mediaPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("media mode=%v", info.Mode())
	}
	directoryInfo, err := os.Stat(filepath.Dir(mediaPath))
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0o700 {
		t.Fatalf("directory mode=%v", directoryInfo.Mode())
	}
}

func TestDuplicateImageMovesToFrontWithoutAddingEntry(t *testing.T) {
	store := clipboard.NewFileHistory(filepath.Join(t.TempDir(), "history.json"))
	first := testPNG(t, 1, 1)
	second := testPNG(t, 2, 1)
	state, err := store.Record(clipboard.EmptyHistory(), first, 25)
	if err != nil {
		t.Fatal(err)
	}
	state, err = store.Record(state, second, 25)
	if err != nil {
		t.Fatal(err)
	}
	state, err = store.Record(state, first, 25)
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Entries) != 2 || state.Entries[0].Width != 1 || state.Entries[1].Width != 2 {
		t.Fatalf("entries = %#v", state.Entries)
	}
}

func TestSaveRemovesDroppedImageAndClearRemovesMediaDirectory(t *testing.T) {
	root := t.TempDir()
	store := clipboard.NewFileHistory(filepath.Join(root, "history.json"))
	state, err := store.Record(clipboard.EmptyHistory(), testPNG(t, 2, 2), 25)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Save(state); err != nil {
		t.Fatal(err)
	}
	mediaPath := strings.TrimPrefix(state.Entries[0].Image, "file://")
	state.Entries = []clipboard.Entry{}
	if err := store.Save(state); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(mediaPath); !os.IsNotExist(err) {
		t.Fatalf("dropped image remains: %v", err)
	}
	state, err = store.Record(state, testPNG(t, 3, 3), 25)
	if err != nil || store.Save(state) != nil || store.Clear() != nil {
		t.Fatalf("record/save/clear failed: %v", err)
	}
	if _, err := store.Load(); err != nil {
		t.Fatal(err)
	}
}

func TestHistoryRejectsMalformedStructuredState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	for name, contents := range map[string]string{
		"unknown":        `{"version":2,"entries":[],"extra":true}`,
		"bad kind":       `{"version":2,"entries":[{"id":"x","kind":"binary"}]}`,
		"bad image path": `{"version":2,"entries":[{"id":"image-x","kind":"image","image":"file:///tmp/x.png","mimeType":"image/png"}]}`,
	} {
		t.Run(name, func(t *testing.T) {
			if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := clipboard.NewFileHistory(path).Load(); err == nil {
				t.Fatal("Load accepted malformed history")
			}
		})
	}
}

func testPNG(t *testing.T, width int, height int) []byte {
	t.Helper()
	picture := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			picture.Set(x, y, color.RGBA{R: uint8(x + 1), G: uint8(y + 1), B: 90, A: 255})
		}
	}
	var output bytes.Buffer
	if err := png.Encode(&output, picture); err != nil {
		t.Fatal(err)
	}
	return output.Bytes()
}
