package config

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

const CurrentVersion = 2

type Config struct {
	Version  int      `json:"version"`
	Bar      Bar      `json:"bar"`
	Clock    Clock    `json:"clock"`
	Calendar Calendar `json:"calendar"`
	Weather  Weather  `json:"weather"`
	Motion   Motion   `json:"motion"`
	Font     Font     `json:"font"`
}

// Font selects the shell-wide font family. An empty family keeps the
// shipped Adwaita defaults. Only Nerd Font families are supported because
// the shell's icons are Nerd Font glyphs.
type Font struct {
	Family string `json:"family"`
}

type Bar struct {
	Outputs          []string  `json:"outputs"`
	Height           int       `json:"height"`
	MarginTop        int       `json:"marginTop"`
	MarginHorizontal int       `json:"marginHorizontal"`
	SystemMetrics    string    `json:"systemMetrics"`
	Layout           BarLayout `json:"layout"`
}

type BarLayout struct {
	Left   []string `json:"left"`
	Center []string `json:"center"`
	Right  []string `json:"right"`
	Hidden []string `json:"hidden"`
}

var knownWidgets = []string{
	"workspaces", "windowTitle", "media", "system", "audio",
	"keyboardLayout", "updates", "clock", "tray", "network",
	"bluetooth", "quickSettings", "notifications", "weather",
	"status", "power",
}

// DefaultBarLayout is the shipped placement for the closed widget set.
func DefaultBarLayout() BarLayout {
	return BarLayout{
		Left:   []string{"workspaces", "windowTitle"},
		Center: []string{"media"},
		Right: []string{
			"system", "audio", "keyboardLayout", "updates", "clock", "tray",
			"bluetooth", "quickSettings", "notifications",
			"weather", "status", "power",
		},
		Hidden: []string{"network"},
	}
}

func defaultLegacyIslands() []string {
	return []string{
		"system", "audio", "keyboardLayout", "updates", "clock", "tray",
		"bluetooth", "control", "notifications", "reminders", "weather", "power",
	}
}

func knownWidget(id string) bool {
	for _, candidate := range knownWidgets {
		if candidate == id {
			return true
		}
	}
	return false
}

// NormalizeBarLayout repairs hand-edited layouts without making widgets
// unexpectedly visible. The first placement wins; excess center widgets and
// every missing known widget move to hidden.
func NormalizeBarLayout(layout BarLayout) BarLayout {
	seen := make(map[string]struct{}, len(knownWidgets))
	result := BarLayout{Left: []string{}, Center: []string{}, Right: []string{}, Hidden: []string{}}
	centerExcess := []string{}

	appendUnique := func(target *[]string, values []string) {
		for _, id := range values {
			if !knownWidget(id) {
				continue
			}
			if _, exists := seen[id]; exists {
				continue
			}
			seen[id] = struct{}{}
			*target = append(*target, id)
		}
	}

	appendUnique(&result.Left, layout.Left)
	for _, id := range layout.Center {
		if !knownWidget(id) {
			continue
		}
		if _, exists := seen[id]; exists {
			continue
		}
		seen[id] = struct{}{}
		if len(result.Center) < 3 {
			result.Center = append(result.Center, id)
		} else {
			centerExcess = append(centerExcess, id)
		}
	}
	appendUnique(&result.Right, layout.Right)
	result.Hidden = append(result.Hidden, centerExcess...)
	appendUnique(&result.Hidden, layout.Hidden)
	for _, id := range knownWidgets {
		if _, exists := seen[id]; !exists {
			result.Hidden = append(result.Hidden, id)
		}
	}
	return result
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
			SystemMetrics:    "separate",
			Layout:           DefaultBarLayout(),
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
		Font: Font{},
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

	var header struct {
		Version int `json:"version"`
	}
	if err := json.Unmarshal(contents, &header); err != nil {
		return Config{}, fmt.Errorf("decode config version: %w", err)
	}

	var result Config
	switch header.Version {
	case 1:
		legacy, err := decodeLegacyConfig(contents)
		if err != nil {
			return Config{}, err
		}
		result = migrateLegacyConfig(legacy)
	case CurrentVersion:
		decoder := json.NewDecoder(bytes.NewReader(contents))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&result); err != nil {
			return Config{}, fmt.Errorf("decode config: %w", err)
		}
	default:
		return Config{}, fmt.Errorf("validate config: version must be 1 or %d", CurrentVersion)
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
	result.Font.Family = strings.TrimSpace(result.Font.Family)
	result.Bar.Layout = NormalizeBarLayout(result.Bar.Layout)
	if err := Validate(result); err != nil {
		return Config{}, fmt.Errorf("validate config: %w", err)
	}

	return result, nil
}

type legacyConfig struct {
	Version  int       `json:"version"`
	Bar      legacyBar `json:"bar"`
	Clock    Clock     `json:"clock"`
	Calendar Calendar  `json:"calendar"`
	Weather  Weather   `json:"weather"`
	Motion   Motion    `json:"motion"`
}

type legacyBar struct {
	Outputs          []string `json:"outputs"`
	Height           int      `json:"height"`
	MarginTop        int      `json:"marginTop"`
	MarginHorizontal int      `json:"marginHorizontal"`
	ShowWindowTitle  bool     `json:"showWindowTitle"`
	ShowMedia        bool     `json:"showMedia"`
	SystemMetrics    string   `json:"systemMetrics"`
	Islands          []string `json:"islands"`
}

func decodeLegacyConfig(contents []byte) (legacyConfig, error) {
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	var result legacyConfig
	if err := decoder.Decode(&result); err != nil {
		return legacyConfig{}, fmt.Errorf("decode config: %w", err)
	}
	return result, nil
}

func migrateLegacyConfig(legacy legacyConfig) Config {
	result := Config{
		Version: CurrentVersion,
		Bar: Bar{
			Outputs:          legacy.Bar.Outputs,
			Height:           legacy.Bar.Height,
			MarginTop:        legacy.Bar.MarginTop,
			MarginHorizontal: legacy.Bar.MarginHorizontal,
			SystemMetrics:    legacy.Bar.SystemMetrics,
		},
		Clock: legacy.Clock, Calendar: legacy.Calendar,
		Weather: legacy.Weather, Motion: legacy.Motion,
	}
	if result.Bar.SystemMetrics == "hidden" {
		result.Bar.SystemMetrics = "separate"
	}

	islands := normalizeLegacyIslands(legacy.Bar.Islands)
	right := make([]string, 0, len(islands)+2)
	for _, id := range islands {
		if id == "reminders" {
			continue
		}
		if id == "bluetooth" {
			right = append(right, "network")
		}
		if id == "control" {
			right = append(right, "quickSettings")
		} else {
			right = append(right, id)
		}
	}
	right = insertBefore(right, "power", "status")

	layout := BarLayout{Left: []string{"workspaces"}, Center: []string{}, Right: right, Hidden: []string{}}
	if legacy.Bar.ShowWindowTitle {
		layout.Left = append(layout.Left, "windowTitle")
	} else {
		layout.Hidden = append(layout.Hidden, "windowTitle")
	}
	if legacy.Bar.ShowMedia {
		layout.Center = append(layout.Center, "media")
	} else {
		layout.Hidden = append(layout.Hidden, "media")
	}
	if legacy.Bar.SystemMetrics == "hidden" {
		layout.Hidden = append(layout.Hidden, "system")
		layout.Right = slicesWithout(layout.Right, "system")
	}
	result.Bar.Layout = NormalizeBarLayout(layout)
	return result
}

func normalizeLegacyIslands(islands []string) []string {
	known := defaultLegacyIslands()
	if len(islands) == 0 {
		return known
	}
	seen := make(map[string]struct{}, len(known))
	result := make([]string, 0, len(known))
	for _, id := range islands {
		if !slices.Contains(known, id) {
			continue
		}
		if _, exists := seen[id]; exists {
			continue
		}
		seen[id] = struct{}{}
		result = append(result, id)
	}
	for _, id := range known {
		if _, exists := seen[id]; !exists {
			result = append(result, id)
		}
	}
	return result
}

func insertBefore(values []string, anchor string, value string) []string {
	for index, current := range values {
		if current == anchor {
			result := append([]string{}, values[:index]...)
			result = append(result, value)
			return append(result, values[index:]...)
		}
	}
	return append(values, value)
}

func slicesWithout(values []string, unwanted string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if value != unwanted {
			result = append(result, value)
		}
	}
	return result
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
	case "separate", "combined":
	default:
		return errors.New("bar.systemMetrics must be separate or combined")
	}
	if err := validateBarLayout(cfg.Bar.Layout); err != nil {
		return err
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
	if utf8.RuneCountInString(cfg.Font.Family) > 80 {
		return errors.New("font.family must contain at most 80 characters")
	}
	for _, character := range cfg.Font.Family {
		if unicode.IsControl(character) {
			return errors.New("font.family must not contain control characters")
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

func validateBarLayout(layout BarLayout) error {
	if len(layout.Center) > 3 {
		return errors.New("bar.layout.center must contain at most 3 widgets")
	}
	seen := make(map[string]string, len(knownWidgets))
	sections := []struct {
		name   string
		values []string
	}{
		{"left", layout.Left},
		{"center", layout.Center},
		{"right", layout.Right},
		{"hidden", layout.Hidden},
	}
	for _, section := range sections {
		for _, id := range section.values {
			if !knownWidget(id) {
				return fmt.Errorf("bar.layout.%s contains unknown widget %q", section.name, id)
			}
			if previous, exists := seen[id]; exists {
				return fmt.Errorf("bar layout contains duplicate widget %q in %s and %s", id, previous, section.name)
			}
			seen[id] = section.name
		}
	}
	for _, id := range knownWidgets {
		if _, exists := seen[id]; !exists {
			return fmt.Errorf("bar layout is missing widget %q", id)
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
	result.Bar.Layout = BarLayout{
		Left:   append([]string(nil), cfg.Bar.Layout.Left...),
		Center: append([]string(nil), cfg.Bar.Layout.Center...),
		Right:  append([]string(nil), cfg.Bar.Layout.Right...),
		Hidden: append([]string(nil), cfg.Bar.Layout.Hidden...),
	}
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
	case "bar.systemMetrics":
		result.Bar.SystemMetrics = parseString(value)
	case "bar.layout":
		var layout BarLayout
		if err := json.Unmarshal([]byte(value), &layout); err != nil {
			return cfg, fmt.Errorf("bar.layout must be a layout object: %w", err)
		}
		result.Bar.Layout = layout
	case "bar.layout.left", "bar.layout.center", "bar.layout.right", "bar.layout.hidden":
		var widgets []string
		if err := json.Unmarshal([]byte(value), &widgets); err != nil {
			return cfg, fmt.Errorf("%s must be a JSON string array: %w", key, err)
		}
		layout := result.Bar.Layout
		switch key {
		case "bar.layout.left":
			layout.Left = widgets
		case "bar.layout.center":
			if len(widgets) > 3 {
				return cfg, errors.New("bar.layout.center must contain at most 3 widgets")
			}
			layout.Center = widgets
		case "bar.layout.right":
			layout.Right = widgets
		case "bar.layout.hidden":
			layout.Hidden = widgets
		}
		result.Bar.Layout = NormalizeBarLayout(layout)
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
	case "font.family":
		result.Font.Family = strings.TrimSpace(parseString(value))
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
	case "bar.systemMetrics":
		value = cfg.Bar.SystemMetrics
	case "bar.layout":
		value = cfg.Bar.Layout
	case "bar.layout.left":
		value = cfg.Bar.Layout.Left
	case "bar.layout.center":
		value = cfg.Bar.Layout.Center
	case "bar.layout.right":
		value = cfg.Bar.Layout.Right
	case "bar.layout.hidden":
		value = cfg.Bar.Layout.Hidden
	case "weather.enabled":
		value = cfg.Weather.Enabled
	case "weather.units":
		value = cfg.Weather.Units
	case "weather.location":
		value = cfg.Weather.Location
	case "font.family":
		value = cfg.Font.Family
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
