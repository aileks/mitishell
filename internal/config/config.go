package config

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

const CurrentVersion = 1

type Config struct {
	Version  int      `json:"version"`
	Bar      Bar      `json:"bar"`
	Clock    Clock    `json:"clock"`
	Calendar Calendar `json:"calendar"`
	Weather  Weather  `json:"weather"`
	Motion   Motion   `json:"motion"`
}

type Bar struct {
	Outputs          []string `json:"outputs"`
	Height           int      `json:"height"`
	MarginTop        int      `json:"marginTop"`
	MarginHorizontal int      `json:"marginHorizontal"`
	ShowWindowTitle  bool     `json:"showWindowTitle"`
	ShowMedia        bool     `json:"showMedia"`
	SystemMetrics    string   `json:"systemMetrics"`
	Islands          []string `json:"islands"`
}

// DefaultIslands is the shipped right-island order.
func DefaultIslands() []string {
	return []string{
		"system", "audio", "keyboardLayout", "updates", "clock", "tray",
		"control", "notifications", "reminders", "weather", "power",
	}
}

func knownIsland(id string) bool {
	switch id {
	case "system", "audio", "keyboardLayout", "updates", "clock", "tray",
		"control", "notifications", "reminders", "weather", "power":
		return true
	}
	return false
}

// NormalizeIslands keeps known ids in the given order, drops unknown and
// duplicate ids, and appends any island missing from the list in default
// order so a stale or hand-edited array still renders every island.
func NormalizeIslands(islands []string) []string {
	seen := make(map[string]struct{}, len(islands))
	normalized := make([]string, 0, len(islands))
	for _, id := range islands {
		if !knownIsland(id) {
			continue
		}
		if _, exists := seen[id]; exists {
			continue
		}
		seen[id] = struct{}{}
		normalized = append(normalized, id)
	}
	for _, id := range DefaultIslands() {
		if _, exists := seen[id]; !exists {
			normalized = append(normalized, id)
		}
	}
	return normalized
}

type Weather struct {
	Enabled  bool   `json:"enabled"`
	Units    string `json:"units"`
	Location string `json:"location"`
}

type Clock struct {
	Format    string   `json:"format"`
	ShowDate  bool     `json:"showDate"`
	Timezones []string `json:"timezones"`
}

type Calendar struct {
	ShowWeekNumbers bool `json:"showWeekNumbers"`
}

type Motion struct {
	Enabled bool `json:"enabled"`
	Reduced bool `json:"reduced"`
}

func Defaults() Config {
	return Config{
		Version: CurrentVersion,
		Bar: Bar{
			Outputs:          []string{"*"},
			Height:           36,
			MarginTop:        6,
			MarginHorizontal: 8,
			ShowWindowTitle:  true,
			ShowMedia:        true,
			SystemMetrics:    "separate",
			Islands:          DefaultIslands(),
		},
		Weather: Weather{
			Units: "auto",
		},
		Clock: Clock{
			Format:    "24h",
			Timezones: []string{},
		},
		Calendar: Calendar{},
		Motion: Motion{
			Enabled: true,
		},
	}
}

func Path() (string, error) {
	directory, err := os.UserConfigDir()
	if err != nil {
		return "", fmt.Errorf("resolve user config directory: %w", err)
	}
	return filepath.Join(directory, "mitishell", "config.json"), nil
}

func Load(path string) (Config, error) {
	_, err := os.Stat(path)
	if errors.Is(err, os.ErrNotExist) {
		return Defaults(), nil
	}
	if err != nil {
		return Config{}, fmt.Errorf("inspect config: %w", err)
	}

	contents, err := os.ReadFile(path)
	if err != nil {
		return Config{}, fmt.Errorf("read config: %w", err)
	}

	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()

	var result Config
	if err := decoder.Decode(&result); err != nil {
		return Config{}, fmt.Errorf("decode config: %w", err)
	}
	// Configs written before the clock section existed decode with an
	// empty format; treat that as "section absent" rather than invalid.
	if result.Clock.Format == "" {
		result.Clock = Defaults().Clock
	}
	if result.Clock.Timezones == nil {
		result.Clock.Timezones = []string{}
	}
	result.Weather.Location = strings.TrimSpace(result.Weather.Location)
	// Islands normalize leniently: unknown ids drop, missing ids append
	// in default order, so hand-edited arrays keep working.
	if len(result.Bar.Islands) == 0 {
		result.Bar.Islands = DefaultIslands()
	} else {
		result.Bar.Islands = NormalizeIslands(result.Bar.Islands)
	}
	if err := Validate(result); err != nil {
		return Config{}, fmt.Errorf("validate config: %w", err)
	}

	return result, nil
}

func Validate(cfg Config) error {
	if cfg.Version != CurrentVersion {
		return fmt.Errorf("version must be %d", CurrentVersion)
	}
	if len(cfg.Bar.Outputs) == 0 {
		return errors.New("bar.outputs must not be empty")
	}
	seenOutputs := make(map[string]struct{}, len(cfg.Bar.Outputs))
	for _, output := range cfg.Bar.Outputs {
		if output == "" {
			return errors.New("bar.outputs must not contain blank connectors")
		}
		if _, exists := seenOutputs[output]; exists {
			return fmt.Errorf("bar.outputs contains duplicate connector %q", output)
		}
		seenOutputs[output] = struct{}{}
	}
	if len(cfg.Bar.Outputs) > 1 {
		for _, output := range cfg.Bar.Outputs {
			if output == "*" {
				return errors.New("bar.outputs wildcard cannot be combined with connectors")
			}
		}
	}
	if cfg.Bar.Height < 24 || cfg.Bar.Height > 96 {
		return errors.New("bar.height must be between 24 and 96")
	}
	if cfg.Bar.MarginTop < 0 || cfg.Bar.MarginTop > 64 {
		return errors.New("bar.marginTop must be between 0 and 64")
	}
	if cfg.Bar.MarginHorizontal < 0 || cfg.Bar.MarginHorizontal > 64 {
		return errors.New("bar.marginHorizontal must be between 0 and 64")
	}
	switch cfg.Bar.SystemMetrics {
	case "separate", "combined", "hidden":
	default:
		return errors.New("bar.systemMetrics must be separate, combined, or hidden")
	}
	switch cfg.Weather.Units {
	case "auto", "celsius", "fahrenheit":
	default:
		return errors.New("weather.units must be auto, celsius, or fahrenheit")
	}
	if utf8.RuneCountInString(cfg.Weather.Location) > 80 {
		return errors.New("weather.location must contain at most 80 characters")
	}
	for _, character := range cfg.Weather.Location {
		if unicode.IsControl(character) {
			return errors.New("weather.location must not contain control characters")
		}
	}
	switch cfg.Clock.Format {
	case "auto", "24h", "12h", "24h-seconds", "12h-seconds":
	default:
		return errors.New("clock.format must be auto, 24h, 12h, 24h-seconds, or 12h-seconds")
	}
	if len(cfg.Clock.Timezones) > 8 {
		return errors.New("clock.timezones must list at most 8 zones")
	}
	seenZones := make(map[string]struct{}, len(cfg.Clock.Timezones))
	for _, zone := range cfg.Clock.Timezones {
		if zone == "" {
			return errors.New("clock.timezones must not contain blank zones")
		}
		if _, exists := seenZones[zone]; exists {
			return fmt.Errorf("clock.timezones contains duplicate zone %q", zone)
		}
		seenZones[zone] = struct{}{}
		if _, err := time.LoadLocation(zone); err != nil {
			return fmt.Errorf("clock.timezones contains unknown zone %q", zone)
		}
	}

	return nil
}

func Write(path string, cfg Config) error {
	if err := Validate(cfg); err != nil {
		return fmt.Errorf("validate config: %w", err)
	}

	contents, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return fmt.Errorf("encode config: %w", err)
	}
	contents = append(contents, '\n')

	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create config directory: %w", err)
	}

	temporary, err := os.CreateTemp(directory, ".config-*.json")
	if err != nil {
		return fmt.Errorf("create temporary config: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set temporary config permissions: %w", err)
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return fmt.Errorf("write temporary config: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync temporary config: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close temporary config: %w", err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return fmt.Errorf("replace config: %w", err)
	}

	return nil
}

func SetField(cfg Config, key string, value string) (Config, error) {
	result := cfg
	result.Bar.Outputs = append([]string(nil), cfg.Bar.Outputs...)
	result.Bar.Islands = append([]string(nil), cfg.Bar.Islands...)
	result.Clock.Timezones = append([]string(nil), cfg.Clock.Timezones...)

	switch key {
	case "bar.outputs":
		var outputs []string
		if err := json.Unmarshal([]byte(value), &outputs); err != nil {
			return cfg, fmt.Errorf("bar.outputs must be a JSON string array: %w", err)
		}
		result.Bar.Outputs = outputs
	case "bar.height":
		parsed, err := strconv.Atoi(value)
		if err != nil {
			return cfg, errors.New("bar.height must be an integer")
		}
		result.Bar.Height = parsed
	case "bar.marginTop":
		parsed, err := strconv.Atoi(value)
		if err != nil {
			return cfg, errors.New("bar.marginTop must be an integer")
		}
		result.Bar.MarginTop = parsed
	case "bar.marginHorizontal":
		parsed, err := strconv.Atoi(value)
		if err != nil {
			return cfg, errors.New("bar.marginHorizontal must be an integer")
		}
		result.Bar.MarginHorizontal = parsed
	case "bar.showWindowTitle":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("bar.showWindowTitle must be true or false")
		}
		result.Bar.ShowWindowTitle = parsed
	case "bar.showMedia":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("bar.showMedia must be true or false")
		}
		result.Bar.ShowMedia = parsed
	case "bar.systemMetrics":
		result.Bar.SystemMetrics = parseString(value)
	case "bar.islands":
		var islands []string
		if err := json.Unmarshal([]byte(value), &islands); err != nil {
			return cfg, fmt.Errorf("bar.islands must be a JSON string array: %w", err)
		}
		result.Bar.Islands = NormalizeIslands(islands)
	case "weather.enabled":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("weather.enabled must be true or false")
		}
		result.Weather.Enabled = parsed
	case "weather.units":
		result.Weather.Units = parseString(value)
	case "weather.location":
		result.Weather.Location = strings.TrimSpace(parseString(value))
	case "clock.format":
		result.Clock.Format = parseString(value)
	case "clock.showDate":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("clock.showDate must be true or false")
		}
		result.Clock.ShowDate = parsed
	case "clock.timezones":
		var zones []string
		if err := json.Unmarshal([]byte(value), &zones); err != nil {
			return cfg, fmt.Errorf("clock.timezones must be a JSON string array: %w", err)
		}
		result.Clock.Timezones = zones
	case "calendar.showWeekNumbers":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("calendar.showWeekNumbers must be true or false")
		}
		result.Calendar.ShowWeekNumbers = parsed
	case "motion.enabled":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("motion.enabled must be true or false")
		}
		result.Motion.Enabled = parsed
	case "motion.reduced":
		parsed, err := strconv.ParseBool(value)
		if err != nil {
			return cfg, errors.New("motion.reduced must be true or false")
		}
		result.Motion.Reduced = parsed
	default:
		return cfg, fmt.Errorf("unknown config field %q", key)
	}

	if err := Validate(result); err != nil {
		return cfg, err
	}
	return result, nil
}

func GetField(cfg Config, key string) (string, error) {
	var value any
	switch key {
	case "version":
		value = cfg.Version
	case "bar.outputs":
		value = cfg.Bar.Outputs
	case "bar.height":
		value = cfg.Bar.Height
	case "bar.marginTop":
		value = cfg.Bar.MarginTop
	case "bar.marginHorizontal":
		value = cfg.Bar.MarginHorizontal
	case "bar.showWindowTitle":
		value = cfg.Bar.ShowWindowTitle
	case "bar.showMedia":
		value = cfg.Bar.ShowMedia
	case "bar.systemMetrics":
		value = cfg.Bar.SystemMetrics
	case "bar.islands":
		value = cfg.Bar.Islands
	case "weather.enabled":
		value = cfg.Weather.Enabled
	case "weather.units":
		value = cfg.Weather.Units
	case "weather.location":
		value = cfg.Weather.Location
	case "clock.format":
		value = cfg.Clock.Format
	case "clock.showDate":
		value = cfg.Clock.ShowDate
	case "clock.timezones":
		value = cfg.Clock.Timezones
	case "calendar.showWeekNumbers":
		value = cfg.Calendar.ShowWeekNumbers
	case "motion.enabled":
		value = cfg.Motion.Enabled
	case "motion.reduced":
		value = cfg.Motion.Reduced
	default:
		return "", fmt.Errorf("unknown config field %q", key)
	}

	encoded, err := json.Marshal(value)
	if err != nil {
		return "", fmt.Errorf("encode %s: %w", key, err)
	}
	return string(encoded), nil
}

func parseString(value string) string {
	var parsed string
	if err := json.Unmarshal([]byte(value), &parsed); err == nil {
		return parsed
	}
	return value
}
