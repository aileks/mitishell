package notifications

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	HistoryVersion = 1
	HistoryLimit   = 50
)

var safeRecordID = regexp.MustCompile(`^[a-zA-Z0-9._-]+$`)

// Entry is the durable, presentation-safe portion of a notification.
// Live actions and QuickShell object identifiers intentionally stay in QML.
type Entry struct {
	RecordID     string `json:"recordId"`
	AppName      string `json:"appName"`
	DesktopEntry string `json:"desktopEntry,omitempty"`
	AppIcon      string `json:"appIcon,omitempty"`
	Image        string `json:"image,omitempty"`
	Summary      string `json:"summary"`
	Body         string `json:"body"`
	Urgency      int    `json:"urgency"`
	Timestamp    int64  `json:"timestamp"`
}

type State struct {
	Version    int     `json:"version"`
	LastSeenAt int64   `json:"lastSeenAt"`
	Entries    []Entry `json:"entries"`
}

type MediaImport struct {
	RecordID  string `json:"recordId"`
	Role      string `json:"role"`
	Source    string `json:"source"`
	Temporary bool   `json:"temporary,omitempty"`
}

type FileHistory struct {
	path     string
	mediaDir string
}

func NewFileHistory(path string) FileHistory {
	return FileHistory{
		path:     path,
		mediaDir: filepath.Join(filepath.Dir(path), "media"),
	}
}

func Path() (string, error) {
	stateRoot := os.Getenv("XDG_STATE_HOME")
	if stateRoot == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve user state directory: %w", err)
		}
		stateRoot = filepath.Join(homeDirectory, ".local", "state")
	}
	return filepath.Join(stateRoot, "mitishell", "notifications", "history.json"), nil
}

func EmptyState() State {
	return State{Version: HistoryVersion, Entries: []Entry{}}
}

func (history FileHistory) Load() (State, error) {
	contents, err := os.ReadFile(history.path)
	if errors.Is(err, os.ErrNotExist) {
		return EmptyState(), nil
	}
	if err != nil {
		return State{}, fmt.Errorf("read notification history: %w", err)
	}

	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	state := State{}
	if err := decoder.Decode(&state); err != nil {
		return State{}, fmt.Errorf("decode notification history: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return State{}, fmt.Errorf("decode notification history: trailing content")
	}
	if err := validateState(state); err != nil {
		return State{}, err
	}
	state.Entries = append([]Entry(nil), state.Entries...)
	return state, nil
}

func (history FileHistory) Save(state State) error {
	state.Version = HistoryVersion
	if len(state.Entries) > HistoryLimit {
		state.Entries = state.Entries[:HistoryLimit]
	}
	if state.Entries == nil {
		state.Entries = []Entry{}
	}
	if err := validateState(state); err != nil {
		return err
	}

	contents, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("encode notification history: %w", err)
	}
	contents = append(contents, '\n')

	directory := filepath.Dir(history.path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create notification state directory: %w", err)
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return fmt.Errorf("set notification state directory permissions: %w", err)
	}
	temporary, err := os.CreateTemp(directory, ".history-*.json")
	if err != nil {
		return fmt.Errorf("create temporary notification history: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set notification history permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write notification history: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync notification history: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close notification history: %w", err)
	}
	if err := os.Rename(temporaryPath, history.path); err != nil {
		return fmt.Errorf("replace notification history: %w", err)
	}
	if err := history.removeOrphanedMedia(state); err != nil {
		return fmt.Errorf("clean notification media: %w", err)
	}
	return nil
}

func (history FileHistory) Clear() error {
	if err := os.Remove(history.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove notification history: %w", err)
	}
	if err := os.RemoveAll(history.mediaDir); err != nil {
		return fmt.Errorf("remove notification media: %w", err)
	}
	return nil
}

func (history FileHistory) ImportMedia(media MediaImport) (string, error) {
	if !safeRecordID.MatchString(media.RecordID) {
		return "", fmt.Errorf("invalid notification record id")
	}
	if media.Role != "appIcon" && media.Role != "image" {
		return "", fmt.Errorf("invalid notification media role")
	}
	sourcePath, err := localPath(media.Source)
	if err != nil {
		return "", err
	}
	info, err := os.Stat(sourcePath)
	if err != nil {
		return "", fmt.Errorf("inspect notification media: %w", err)
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("notification media is not a regular file")
	}

	if err := os.MkdirAll(history.mediaDir, 0o700); err != nil {
		return "", fmt.Errorf("create notification media directory: %w", err)
	}
	if err := os.Chmod(history.mediaDir, 0o700); err != nil {
		return "", fmt.Errorf("set notification media directory permissions: %w", err)
	}
	extension := strings.ToLower(filepath.Ext(sourcePath))
	if len(extension) > 8 || extension == "" {
		extension = ".img"
	}
	destination := filepath.Join(history.mediaDir, media.RecordID+"-"+media.Role+extension)
	if err := copyPrivateFile(sourcePath, destination); err != nil {
		return "", err
	}
	if media.Temporary {
		_ = os.Remove(sourcePath)
	}
	return (&url.URL{Scheme: "file", Path: destination}).String(), nil
}

func validateState(state State) error {
	if state.Version != HistoryVersion {
		return fmt.Errorf("unsupported notification history version %d", state.Version)
	}
	if state.LastSeenAt < 0 {
		return fmt.Errorf("notification last-seen time cannot be negative")
	}
	if len(state.Entries) > HistoryLimit {
		return fmt.Errorf("notification history exceeds %d entries", HistoryLimit)
	}
	seen := make(map[string]struct{}, len(state.Entries))
	for _, entry := range state.Entries {
		if !safeRecordID.MatchString(entry.RecordID) {
			return fmt.Errorf("invalid notification record id %q", entry.RecordID)
		}
		if _, exists := seen[entry.RecordID]; exists {
			return fmt.Errorf("duplicate notification record id %q", entry.RecordID)
		}
		seen[entry.RecordID] = struct{}{}
		if entry.Urgency < 0 || entry.Urgency > 2 {
			return fmt.Errorf("invalid notification urgency %d", entry.Urgency)
		}
		if entry.Timestamp < 0 {
			return fmt.Errorf("notification timestamp cannot be negative")
		}
	}
	return nil
}

func localPath(value string) (string, error) {
	if strings.HasPrefix(value, "file:") {
		parsed, err := url.Parse(value)
		if err != nil || parsed.Scheme != "file" || parsed.Host != "" {
			return "", fmt.Errorf("invalid notification media file URL")
		}
		value = parsed.Path
	}
	if !filepath.IsAbs(value) {
		return "", fmt.Errorf("notification media path must be absolute")
	}
	return filepath.Clean(value), nil
}

func copyPrivateFile(sourcePath string, destination string) error {
	source, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("open notification media: %w", err)
	}
	defer source.Close()

	temporary, err := os.CreateTemp(filepath.Dir(destination), ".media-*")
	if err != nil {
		return fmt.Errorf("create temporary notification media: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set notification media permissions: %w", err)
	}
	if _, err := io.Copy(temporary, source); err != nil {
		temporary.Close()
		return fmt.Errorf("copy notification media: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close notification media: %w", err)
	}
	if err := os.Rename(temporaryPath, destination); err != nil {
		return fmt.Errorf("replace notification media: %w", err)
	}
	return nil
}

func (history FileHistory) removeOrphanedMedia(state State) error {
	referenced := make(map[string]struct{})
	for _, entry := range state.Entries {
		for _, value := range []string{entry.AppIcon, entry.Image} {
			path, err := localPath(value)
			if err == nil && filepath.Dir(path) == history.mediaDir {
				referenced[filepath.Base(path)] = struct{}{}
			}
		}
	}
	entries, err := os.ReadDir(history.mediaDir)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if _, keep := referenced[entry.Name()]; !keep {
			if err := os.Remove(filepath.Join(history.mediaDir, entry.Name())); err != nil {
				return err
			}
		}
	}
	return nil
}
