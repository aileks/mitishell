// Package emoji owns the durable recent-emoji state used by the picker.
package emoji

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	RecentsVersion = 1
	RecentsLimit   = 24
)

type Recents struct {
	Version int      `json:"version"`
	Entries []string `json:"entries"`
}

type FileRecents struct {
	path string
}

func NewFileRecents(path string) FileRecents {
	return FileRecents{path: path}
}

func RecentsPath() (string, error) {
	stateRoot := os.Getenv("XDG_STATE_HOME")
	if stateRoot == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve user state directory: %w", err)
		}
		stateRoot = filepath.Join(homeDirectory, ".local", "state")
	}
	return filepath.Join(stateRoot, "mitishell", "emoji-recents.json"), nil
}

func EmptyRecents() Recents {
	return Recents{Version: RecentsVersion, Entries: []string{}}
}

func (recents FileRecents) Load() (Recents, error) {
	contents, err := os.ReadFile(recents.path)
	if errors.Is(err, os.ErrNotExist) {
		return EmptyRecents(), nil
	}
	if err != nil {
		return Recents{}, fmt.Errorf("read emoji recents: %w", err)
	}

	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	state := Recents{}
	if err := decoder.Decode(&state); err != nil {
		return Recents{}, fmt.Errorf("decode emoji recents: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return Recents{}, fmt.Errorf("decode emoji recents: trailing content")
	}
	if err := validateRecents(state); err != nil {
		return Recents{}, err
	}
	state.Entries = append([]string(nil), state.Entries...)
	return state, nil
}

func (recents FileRecents) Save(state Recents) error {
	state.Version = RecentsVersion
	state.Entries = normalizeEntries(state.Entries)
	if err := validateRecents(state); err != nil {
		return err
	}

	contents, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("encode emoji recents: %w", err)
	}
	contents = append(contents, '\n')

	directory := filepath.Dir(recents.path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create emoji state directory: %w", err)
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return fmt.Errorf("set emoji state directory permissions: %w", err)
	}
	temporary, err := os.CreateTemp(directory, ".emoji-recents-*.json")
	if err != nil {
		return fmt.Errorf("create temporary emoji recents: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set emoji recents permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write emoji recents: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync emoji recents: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close emoji recents: %w", err)
	}
	if err := os.Rename(temporaryPath, recents.path); err != nil {
		return fmt.Errorf("replace emoji recents: %w", err)
	}
	return nil
}

func (recents FileRecents) Clear() error {
	if err := os.Remove(recents.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove emoji recents: %w", err)
	}
	return nil
}

func normalizeEntries(entries []string) []string {
	seen := make(map[string]struct{}, len(entries))
	normalized := make([]string, 0, min(len(entries), RecentsLimit))
	for _, entry := range entries {
		if _, exists := seen[entry]; exists {
			continue
		}
		seen[entry] = struct{}{}
		normalized = append(normalized, entry)
		if len(normalized) == RecentsLimit {
			break
		}
	}
	return normalized
}

func validateRecents(state Recents) error {
	if state.Version != RecentsVersion {
		return fmt.Errorf("unsupported emoji recents version %d", state.Version)
	}
	if len(state.Entries) > RecentsLimit {
		return fmt.Errorf("emoji recents exceed %d entries", RecentsLimit)
	}
	seen := make(map[string]struct{}, len(state.Entries))
	for _, entry := range state.Entries {
		if !utf8.ValidString(entry) || strings.TrimSpace(entry) == "" || utf8.RuneCountInString(entry) > 32 {
			return fmt.Errorf("invalid recent emoji")
		}
		for _, character := range entry {
			if unicode.IsControl(character) {
				return fmt.Errorf("recent emoji contains control characters")
			}
		}
		if _, exists := seen[entry]; exists {
			return fmt.Errorf("duplicate recent emoji")
		}
		seen[entry] = struct{}{}
	}
	return nil
}
