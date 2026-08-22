package display

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Cache persists discovered displays between runs.
type Cache interface {
	Load() ([]Display, error)
	Save([]Display) error
}

type FileCache struct {
	path string
}

func NewFileCache(path string) FileCache {
	return FileCache{path: path}
}

func (cache FileCache) Load() ([]Display, error) {
	contents, err := os.ReadFile(cache.path)
	if err != nil {
		return nil, fmt.Errorf("read cache: %w", err)
	}

	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	var displays []Display
	if err := decoder.Decode(&displays); err != nil {
		return nil, fmt.Errorf("decode cache: %w", err)
	}
	return displays, nil
}

func (cache FileCache) Save(displays []Display) error {
	contents, err := json.Marshal(displays)
	if err != nil {
		return fmt.Errorf("encode cache: %w", err)
	}
	contents = append(contents, '\n')

	directory := filepath.Dir(cache.path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create cache directory: %w", err)
	}
	temporary, err := os.CreateTemp(directory, ".displays-*.json")
	if err != nil {
		return fmt.Errorf("create temporary cache: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set cache permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write cache: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close cache: %w", err)
	}
	if err := os.Rename(temporaryPath, cache.path); err != nil {
		return fmt.Errorf("replace cache: %w", err)
	}
	return nil
}
