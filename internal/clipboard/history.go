// Package clipboard owns the durable clipboard history used by the launcher.
package clipboard

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/aileks/mitishell/internal/statefile"
)

const (
	HistoryVersion = 1
	// HistoryLimit matches the largest clipboard.maxEntries the config
	// accepts, so the store never holds more than any cap allows.
	HistoryLimit = 100
	// MaxEntryRunes keeps single copies from bloating the state file.
	MaxEntryRunes = 10000
)

type History struct {
	Version int      `json:"version"`
	Entries []string `json:"entries"`
}

type FileHistory struct {
	file statefile.JSON
}

func NewFileHistory(path string) FileHistory {
	return FileHistory{file: statefile.NewJSON(path, "clipboard history")}
}

func HistoryPath() (string, error) {
	return statefile.Path("clipboard-history.json")
}

func EmptyHistory() History {
	return History{Version: HistoryVersion, Entries: []string{}}
}

// Record merges one copied text into a history and returns the updated
// history: blank, invalid, or oversize text is skipped, duplicates move
// to the top, and maxEntries bounds the result.
func Record(history History, text string, maxEntries int) History {
	if !utf8.ValidString(text) || strings.TrimSpace(text) == "" {
		return history
	}
	if utf8.RuneCountInString(text) > MaxEntryRunes || maxEntries <= 0 {
		return history
	}
	entries := []string{text}
	for _, entry := range history.Entries {
		if entry != text {
			entries = append(entries, entry)
		}
	}
	if len(entries) > maxEntries {
		entries = entries[:maxEntries]
	}
	return History{Version: HistoryVersion, Entries: entries}
}

func (history FileHistory) Load() (History, error) {
	state := EmptyHistory()
	found, err := history.file.Load(&state)
	if err != nil {
		return History{}, err
	}
	if !found {
		return state, nil
	}
	if err := validateHistory(state); err != nil {
		return History{}, err
	}
	state.Entries = append([]string(nil), state.Entries...)
	return state, nil
}

func (history FileHistory) Save(state History) error {
	state.Version = HistoryVersion
	state.Entries = normalizeEntries(state.Entries)
	if err := validateHistory(state); err != nil {
		return err
	}

	return history.file.Save(state)
}

func (history FileHistory) Clear() error {
	return history.file.Clear()
}

func normalizeEntries(entries []string) []string {
	seen := make(map[string]struct{}, len(entries))
	normalized := make([]string, 0, min(len(entries), HistoryLimit))
	for _, entry := range entries {
		if _, exists := seen[entry]; exists {
			continue
		}
		seen[entry] = struct{}{}
		normalized = append(normalized, entry)
		if len(normalized) == HistoryLimit {
			break
		}
	}
	return normalized
}

func validateHistory(state History) error {
	if state.Version != HistoryVersion {
		return fmt.Errorf("unsupported clipboard history version %d", state.Version)
	}
	if len(state.Entries) > HistoryLimit {
		return fmt.Errorf("clipboard history exceeds %d entries", HistoryLimit)
	}
	seen := make(map[string]struct{}, len(state.Entries))
	for _, entry := range state.Entries {
		if !utf8.ValidString(entry) || strings.TrimSpace(entry) == "" {
			return fmt.Errorf("invalid clipboard entry")
		}
		if utf8.RuneCountInString(entry) > MaxEntryRunes {
			return fmt.Errorf("clipboard entry exceeds %d runes", MaxEntryRunes)
		}
		if _, exists := seen[entry]; exists {
			return fmt.Errorf("duplicate clipboard entry")
		}
		seen[entry] = struct{}{}
	}
	return nil
}
