// Package emoji owns the durable recent-emoji state used by the picker.
package emoji

import (
	"fmt"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/aileks/mitishell/internal/statefile"
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
	file statefile.JSON
}

func NewFileRecents(path string) FileRecents {
	return FileRecents{file: statefile.NewJSON(path, "emoji recents")}
}

func RecentsPath() (string, error) {
	return statefile.Path("emoji-recents.json")
}

func EmptyRecents() Recents {
	return Recents{Version: RecentsVersion, Entries: []string{}}
}

func (recents FileRecents) Load() (Recents, error) {
	state := EmptyRecents()
	found, err := recents.file.Load(&state)
	if err != nil {
		return Recents{}, err
	}
	if !found {
		return state, nil
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

	return recents.file.Save(state)
}

func (recents FileRecents) Clear() error {
	return recents.file.Clear()
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
