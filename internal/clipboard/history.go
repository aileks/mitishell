// Package clipboard owns the durable clipboard history used by the launcher.
package clipboard

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"

	"github.com/aileks/mitishell/internal/statefile"
)

const (
	HistoryVersion = 2
	HistoryLimit   = 100
	MaxEntryRunes  = 10000
	MaxImageBytes  = 20 * 1024 * 1024
)

type Kind string

const (
	KindText  Kind = "text"
	KindImage Kind = "image"
)

type Entry struct {
	ID       string `json:"id"`
	Kind     Kind   `json:"kind"`
	Text     string `json:"text,omitempty"`
	Image    string `json:"image,omitempty"`
	MimeType string `json:"mimeType,omitempty"`
	Width    int    `json:"width,omitempty"`
	Height   int    `json:"height,omitempty"`
}

type History struct {
	Version int     `json:"version"`
	Entries []Entry `json:"entries"`
}

type legacyHistory struct {
	Version int      `json:"version"`
	Entries []string `json:"entries"`
}

type FileHistory struct {
	path     string
	mediaDir string
	file     statefile.JSON
}

func NewFileHistory(path string) FileHistory {
	return FileHistory{
		path:     path,
		mediaDir: filepath.Join(filepath.Dir(path), "clipboard-media"),
		file:     statefile.NewJSON(path, "clipboard history"),
	}
}

func HistoryPath() (string, error) {
	return statefile.Path("clipboard-history.json")
}

func EmptyHistory() History {
	return History{Version: HistoryVersion, Entries: []Entry{}}
}

func RecordText(history History, text string, maxEntries int) History {
	if !utf8.ValidString(text) || strings.TrimSpace(text) == "" || maxEntries <= 0 {
		return history
	}
	if utf8.RuneCountInString(text) > MaxEntryRunes {
		return history
	}
	entry := Entry{ID: contentID("text", []byte(text)), Kind: KindText, Text: text}
	return addEntry(history, entry, maxEntries)
}

// Record classifies clipboard bytes, stores supported images, and returns the
// updated history. Unsupported binary data is ignored.
func (history FileHistory) Record(state History, contents []byte, maxEntries int) (History, error) {
	if len(contents) == 0 || maxEntries <= 0 {
		return state, nil
	}
	mimeType := strings.Split(http.DetectContentType(contents), ";")[0]
	if strings.HasPrefix(mimeType, "image/") {
		return history.recordImage(state, contents, mimeType, maxEntries)
	}
	if !strings.HasPrefix(mimeType, "text/") {
		return state, nil
	}
	return RecordText(state, string(contents), maxEntries), nil
}

func (history FileHistory) recordImage(
	state History,
	contents []byte,
	mimeType string,
	maxEntries int,
) (History, error) {
	if len(contents) > MaxImageBytes {
		return state, nil
	}
	id := contentID("image", contents)
	extension := imageExtension(mimeType)
	if extension == "" {
		return state, nil
	}
	if err := os.MkdirAll(history.mediaDir, 0o700); err != nil {
		return state, fmt.Errorf("create clipboard media directory: %w", err)
	}
	if err := os.Chmod(history.mediaDir, 0o700); err != nil {
		return state, fmt.Errorf("set clipboard media directory permissions: %w", err)
	}
	path := filepath.Join(history.mediaDir, id+extension)
	if err := writePrivateFile(path, contents); err != nil {
		return state, err
	}
	width, height := 0, 0
	if config, _, err := image.DecodeConfig(bytes.NewReader(contents)); err == nil {
		width, height = config.Width, config.Height
	}
	entry := Entry{
		ID:       id,
		Kind:     KindImage,
		Image:    (&url.URL{Scheme: "file", Path: path}).String(),
		MimeType: mimeType,
		Width:    width,
		Height:   height,
	}
	return addEntry(state, entry, maxEntries), nil
}

func (history FileHistory) Load() (History, error) {
	contents, err := os.ReadFile(history.path)
	if errors.Is(err, os.ErrNotExist) {
		return EmptyHistory(), nil
	}
	if err != nil {
		return History{}, fmt.Errorf("read clipboard history: %w", err)
	}
	var header struct {
		Version int `json:"version"`
	}
	if err := json.Unmarshal(contents, &header); err != nil {
		return History{}, fmt.Errorf("decode clipboard history version: %w", err)
	}
	if header.Version == 1 {
		legacy := legacyHistory{}
		if err := decodeStrict(contents, &legacy); err != nil {
			return History{}, fmt.Errorf("decode clipboard history: %w", err)
		}
		state := EmptyHistory()
		for index := len(legacy.Entries) - 1; index >= 0; index-- {
			state = RecordText(state, legacy.Entries[index], HistoryLimit)
		}
		if len(state.Entries) != len(legacy.Entries) {
			return History{}, fmt.Errorf("invalid legacy clipboard entry")
		}
		return state, nil
	}
	state := EmptyHistory()
	if err := decodeStrict(contents, &state); err != nil {
		return History{}, fmt.Errorf("decode clipboard history: %w", err)
	}
	if err := history.validate(state); err != nil {
		return History{}, err
	}
	state.Entries = append([]Entry(nil), state.Entries...)
	return state, nil
}

func (history FileHistory) Save(state History) error {
	state.Version = HistoryVersion
	state.Entries = normalizeEntries(state.Entries)
	if err := history.validate(state); err != nil {
		return err
	}
	if err := history.file.Save(state); err != nil {
		return err
	}
	return history.removeOrphanedMedia(state)
}

func (history FileHistory) Clear() error {
	if err := history.file.Clear(); err != nil {
		return err
	}
	if err := os.RemoveAll(history.mediaDir); err != nil {
		return fmt.Errorf("remove clipboard media: %w", err)
	}
	return nil
}

func (history FileHistory) ImageData(id string) (Entry, []byte, error) {
	state, err := history.Load()
	if err != nil {
		return Entry{}, nil, err
	}
	for _, entry := range state.Entries {
		if entry.ID != id || entry.Kind != KindImage {
			continue
		}
		path, err := history.mediaPath(entry.Image)
		if err != nil {
			return Entry{}, nil, err
		}
		contents, err := os.ReadFile(path)
		if err != nil {
			return Entry{}, nil, fmt.Errorf("read clipboard image: %w", err)
		}
		if len(contents) > MaxImageBytes {
			return Entry{}, nil, fmt.Errorf("clipboard image exceeds %d bytes", MaxImageBytes)
		}
		return entry, contents, nil
	}
	return Entry{}, nil, fmt.Errorf("clipboard image not found")
}

func addEntry(history History, entry Entry, maxEntries int) History {
	entries := []Entry{entry}
	for _, current := range history.Entries {
		if current.ID != entry.ID {
			entries = append(entries, current)
		}
	}
	if len(entries) > maxEntries {
		entries = entries[:maxEntries]
	}
	return History{Version: HistoryVersion, Entries: entries}
}

func normalizeEntries(entries []Entry) []Entry {
	seen := make(map[string]struct{}, len(entries))
	normalized := make([]Entry, 0, min(len(entries), HistoryLimit))
	for _, entry := range entries {
		if _, exists := seen[entry.ID]; exists {
			continue
		}
		seen[entry.ID] = struct{}{}
		normalized = append(normalized, entry)
		if len(normalized) == HistoryLimit {
			break
		}
	}
	return normalized
}

func (history FileHistory) validate(state History) error {
	if state.Version != HistoryVersion {
		return fmt.Errorf("unsupported clipboard history version %d", state.Version)
	}
	if len(state.Entries) > HistoryLimit {
		return fmt.Errorf("clipboard history exceeds %d entries", HistoryLimit)
	}
	seen := make(map[string]struct{}, len(state.Entries))
	for _, entry := range state.Entries {
		if entry.ID == "" {
			return fmt.Errorf("clipboard entry has no id")
		}
		if _, exists := seen[entry.ID]; exists {
			return fmt.Errorf("duplicate clipboard entry")
		}
		seen[entry.ID] = struct{}{}
		switch entry.Kind {
		case KindText:
			if entry.ID != contentID("text", []byte(entry.Text)) || !utf8.ValidString(entry.Text) ||
				strings.TrimSpace(entry.Text) == "" || utf8.RuneCountInString(entry.Text) > MaxEntryRunes ||
				entry.Image != "" || entry.MimeType != "" || entry.Width != 0 || entry.Height != 0 {
				return fmt.Errorf("invalid text clipboard entry")
			}
		case KindImage:
			if !strings.HasPrefix(entry.MimeType, "image/") || imageExtension(entry.MimeType) == "" ||
				entry.Text != "" || entry.Width < 0 || entry.Height < 0 {
				return fmt.Errorf("invalid image clipboard entry")
			}
			path, err := history.mediaPath(entry.Image)
			if err != nil {
				return err
			}
			if !strings.HasPrefix(filepath.Base(path), entry.ID+".") {
				return fmt.Errorf("clipboard image id does not match its file")
			}
		default:
			return fmt.Errorf("invalid clipboard entry kind %q", entry.Kind)
		}
	}
	return nil
}

func (history FileHistory) mediaPath(value string) (string, error) {
	parsed, err := url.Parse(value)
	if err != nil || parsed.Scheme != "file" || parsed.Host != "" || !filepath.IsAbs(parsed.Path) {
		return "", fmt.Errorf("invalid clipboard image URL")
	}
	path := filepath.Clean(parsed.Path)
	if filepath.Dir(path) != history.mediaDir {
		return "", fmt.Errorf("clipboard image is outside the media directory")
	}
	return path, nil
}

func (history FileHistory) removeOrphanedMedia(state History) error {
	referenced := make(map[string]struct{})
	for _, entry := range state.Entries {
		if entry.Kind != KindImage {
			continue
		}
		if path, err := history.mediaPath(entry.Image); err == nil {
			referenced[filepath.Base(path)] = struct{}{}
		}
	}
	entries, err := os.ReadDir(history.mediaDir)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read clipboard media directory: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if _, keep := referenced[entry.Name()]; !keep {
			if err := os.Remove(filepath.Join(history.mediaDir, entry.Name())); err != nil {
				return fmt.Errorf("remove clipboard media: %w", err)
			}
		}
	}
	return nil
}

func contentID(prefix string, contents []byte) string {
	hash := sha256.Sum256(contents)
	return prefix + "-" + hex.EncodeToString(hash[:16])
}

func imageExtension(mimeType string) string {
	switch mimeType {
	case "image/png":
		return ".png"
	case "image/jpeg":
		return ".jpg"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	case "image/bmp":
		return ".bmp"
	default:
		return ""
	}
}

func writePrivateFile(path string, contents []byte) error {
	temporary, err := os.CreateTemp(filepath.Dir(path), ".clipboard-*")
	if err != nil {
		return fmt.Errorf("create temporary clipboard image: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set clipboard image permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write clipboard image: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close clipboard image: %w", err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return fmt.Errorf("replace clipboard image: %w", err)
	}
	return nil
}

func decodeStrict(contents []byte, target any) error {
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return fmt.Errorf("trailing content")
	}
	return nil
}
