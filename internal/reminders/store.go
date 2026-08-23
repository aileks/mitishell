package reminders

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
)

type Store interface {
	Load(string) (Record, error)
	LoadAll() ([]Record, error)
	Save(Record) error
	Remove(string) error
	Clear() error
}

type FileStore struct {
	directory string
}

func RuntimeDirectory() (string, error) {
	runtimeRoot := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeRoot == "" {
		return "", fmt.Errorf("XDG_RUNTIME_DIR is unavailable")
	}
	if !filepath.IsAbs(runtimeRoot) {
		return "", fmt.Errorf("XDG_RUNTIME_DIR must be absolute")
	}
	return filepath.Join(runtimeRoot, "mitishell", "reminders"), nil
}

func NewFileStore(directory string) FileStore {
	return FileStore{directory: directory}
}

func (store FileStore) Load(id string) (Record, error) {
	if !safeID.MatchString(id) {
		return Record{}, fmt.Errorf("invalid reminder id")
	}
	contents, err := os.ReadFile(store.path(id))
	if err != nil {
		return Record{}, fmt.Errorf("read reminder metadata: %w", err)
	}
	record, err := decodeRecord(contents)
	if err != nil {
		return Record{}, err
	}
	if record.ID != id {
		return Record{}, fmt.Errorf("reminder metadata id mismatch")
	}
	return record, nil
}

func (store FileStore) LoadAll() ([]Record, error) {
	entries, err := os.ReadDir(store.directory)
	if errors.Is(err, os.ErrNotExist) {
		return []Record{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read reminder metadata directory: %w", err)
	}
	records := make([]Record, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		id := entry.Name()[:len(entry.Name())-len(".json")]
		record, err := store.Load(id)
		if err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	sort.Slice(records, func(left int, right int) bool {
		return records[left].FireAt < records[right].FireAt
	})
	return records, nil
}

func (store FileStore) Save(record Record) error {
	if err := record.validate(); err != nil {
		return err
	}
	contents, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("encode reminder metadata: %w", err)
	}
	contents = append(contents, '\n')
	if err := os.MkdirAll(store.directory, 0o700); err != nil {
		return fmt.Errorf("create reminder metadata directory: %w", err)
	}
	if err := os.Chmod(store.directory, 0o700); err != nil {
		return fmt.Errorf("set reminder metadata directory permissions: %w", err)
	}
	temporary, err := os.CreateTemp(store.directory, ".reminder-*.json")
	if err != nil {
		return fmt.Errorf("create temporary reminder metadata: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set reminder metadata permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write reminder metadata: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync reminder metadata: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close reminder metadata: %w", err)
	}
	if err := os.Rename(temporaryPath, store.path(record.ID)); err != nil {
		return fmt.Errorf("replace reminder metadata: %w", err)
	}
	return nil
}

func (store FileStore) Remove(id string) error {
	if !safeID.MatchString(id) {
		return fmt.Errorf("invalid reminder id")
	}
	if err := os.Remove(store.path(id)); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove reminder metadata: %w", err)
	}
	return nil
}

func (store FileStore) Clear() error {
	if err := os.RemoveAll(store.directory); err != nil {
		return fmt.Errorf("clear reminder metadata: %w", err)
	}
	return nil
}

func (store FileStore) path(id string) string {
	return filepath.Join(store.directory, id+".json")
}

func decodeRecord(contents []byte) (Record, error) {
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	record := Record{}
	if err := decoder.Decode(&record); err != nil {
		return Record{}, fmt.Errorf("decode reminder metadata: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return Record{}, fmt.Errorf("decode reminder metadata: trailing content")
	}
	if err := record.validate(); err != nil {
		return Record{}, err
	}
	return record, nil
}
