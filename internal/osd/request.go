package osd

import (
	"fmt"
	"math"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

const (
	DefaultDurationMS = 1200
	MinimumDurationMS = 250
	MaximumDurationMS = 30000
)

type Request struct {
	Icon       string
	Message    string
	Progress   *float64
	DurationMS int
}

func NewRequest(icon string, message string, progress *float64, durationMS float64) (Request, error) {
	if icon == "" && message == "" && progress == nil {
		return Request{}, fmt.Errorf("at least one of icon, message, or progress is required")
	}
	if progress != nil && (!isFinite(*progress) || *progress < 0 || *progress > 100) {
		return Request{}, fmt.Errorf("progress must be a finite value from 0 through 100")
	}
	if !isFinite(durationMS) || durationMS < MinimumDurationMS || durationMS > MaximumDurationMS {
		return Request{}, fmt.Errorf(
			"duration must be a finite value from %d through %d milliseconds",
			MinimumDurationMS,
			MaximumDurationMS,
		)
	}
	normalizedIcon, err := normalizeIcon(icon)
	if err != nil {
		return Request{}, err
	}
	return Request{
		Icon:       normalizedIcon,
		Message:    message,
		Progress:   progress,
		DurationMS: int(math.Round(durationMS)),
	}, nil
}

func normalizeIcon(icon string) (string, error) {
	if icon == "" {
		return "", nil
	}
	lower := strings.ToLower(icon)
	if strings.HasPrefix(lower, "file:") {
		parsed, err := url.Parse(icon)
		if err != nil ||
			!strings.EqualFold(parsed.Scheme, "file") ||
			parsed.Host != "" ||
			parsed.RawQuery != "" ||
			parsed.Fragment != "" {
			return "", fmt.Errorf("icon file URL is invalid")
		}
		return readableLocalIcon(parsed.Path)
	}
	if filepath.IsAbs(icon) {
		return readableLocalIcon(icon)
	}
	if strings.Contains(icon, "://") {
		return "", fmt.Errorf("remote icon URLs are not supported")
	}
	return icon, nil
}

func readableLocalIcon(path string) (string, error) {
	path = filepath.Clean(path)
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("inspect icon file: %w", err)
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("icon path is not a regular file")
	}
	file, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("read icon file: %w", err)
	}
	if err := file.Close(); err != nil {
		return "", fmt.Errorf("close icon file: %w", err)
	}
	return (&url.URL{Scheme: "file", Path: path}).String(), nil
}

func isFinite(value float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0)
}
