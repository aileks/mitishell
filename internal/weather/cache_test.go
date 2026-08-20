package weather_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/weather"
)

func TestFileCachePersistsOnlyNormalizedSnapshot(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mitishell", "weather.json")
	cache := weather.NewFileCache(path)
	want := weather.Snapshot{
		UpdatedAt: time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC),
		Units:     weather.Celsius,
		Current:   weather.Current{Temperature: 22.5, WeatherCode: 2},
		Hourly:    []weather.Hour{{Time: "2026-08-20T19:00", Temperature: 22.5}},
		Daily:     []weather.Day{{Date: "2026-08-20", Minimum: 17, Maximum: 25}},
	}

	if err := cache.Save(want); err != nil {
		t.Fatal(err)
	}
	got, err := cache.Load()
	if err != nil {
		t.Fatal(err)
	}
	if got.Current.Temperature != want.Current.Temperature || len(got.Hourly) != 1 || len(got.Daily) != 1 {
		t.Fatalf("loaded snapshot = %#v", got)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if gotMode := info.Mode().Perm(); gotMode != 0o600 {
		t.Fatalf("cache mode = %o, want 600", gotMode)
	}
}

func TestFileCacheRejectsUnknownFields(t *testing.T) {
	path := filepath.Join(t.TempDir(), "weather.json")
	if err := os.WriteFile(path, []byte(`{"latitude":40.7}`), 0o600); err != nil {
		t.Fatal(err)
	}

	if _, err := weather.NewFileCache(path).Load(); err == nil {
		t.Fatal("Load() accepted an unknown coordinate field")
	}
}
