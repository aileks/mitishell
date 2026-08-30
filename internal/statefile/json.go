// Package statefile stores small private JSON state files safely.
package statefile

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type JSON struct {
	path  string
	label string
}

func NewJSON(path, label string) JSON {
	return JSON{path: path, label: label}
}

func Path(filename string) (string, error) {
	stateRoot := os.Getenv("XDG_STATE_HOME")
	if stateRoot == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve user state directory: %w", err)
		}
		stateRoot = filepath.Join(homeDirectory, ".local", "state")
	}
	return filepath.Join(stateRoot, "mitishell", filename), nil
}

// Load decodes one strict JSON value. A missing file leaves target unchanged.
func (file JSON) Load(target any) (bool, error) {
	contents, err := os.ReadFile(file.path)
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("read %s: %w", file.label, err)
	}

	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return false, fmt.Errorf("decode %s: %w", file.label, err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return false, fmt.Errorf("decode %s: trailing content", file.label)
	}
	return true, nil
}

// Save atomically replaces the file after syncing its private temporary file.
func (file JSON) Save(value any) error {
	contents, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("encode %s: %w", file.label, err)
	}
	contents = append(contents, '\n')

	directory := filepath.Dir(file.path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create state directory for %s: %w", file.label, err)
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return fmt.Errorf("set state directory permissions for %s: %w", file.label, err)
	}

	temporary, err := os.CreateTemp(directory, ".mitishell-state-*.tmp")
	if err != nil {
		return fmt.Errorf("create temporary %s: %w", file.label, err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set %s permissions: %w", file.label, err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write %s: %w", file.label, err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync %s: %w", file.label, err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close %s: %w", file.label, err)
	}
	if err := os.Rename(temporaryPath, file.path); err != nil {
		return fmt.Errorf("replace %s: %w", file.label, err)
	}
	return nil
}

func (file JSON) Clear() error {
	if err := os.Remove(file.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove %s: %w", file.label, err)
	}
	return nil
}
