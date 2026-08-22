package display

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// DDC/CI brightness for connected monitors. Discovery maps DRM connectors to
// i2c buses through sysfs, probes each bus with ddcutil, and caches the
// result so later runs skip probing while the connector-to-bus mapping is
// stable. Brightness values are normalized to 0-100 regardless of the range
// a monitor reports for VCP feature 0x10.

const commandTimeout = 10 * time.Second

var ErrUnavailable = errors.New("ddcutil unavailable")

type State string

const (
	Ready       State = "ready"
	Unavailable State = "unavailable"
)

type Display struct {
	Connector  string `json:"connector"`
	Bus        int    `json:"bus"`
	Brightness int    `json:"brightness"`
	Max        int    `json:"max"`
}

type Result struct {
	State    State     `json:"state"`
	Displays []Display `json:"displays"`
	Error    string    `json:"error,omitempty"`
}

// Runner executes one ddcutil invocation and returns its combined output.
type Runner func(ctx context.Context, args ...string) (string, error)

// NewSystemRunner returns a Runner over the installed ddcutil binary, or an
// error wrapping ErrUnavailable when ddcutil is missing.
func NewSystemRunner() (Runner, error) {
	path, err := exec.LookPath("ddcutil")
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	return func(ctx context.Context, args ...string) (string, error) {
		ctx, cancel := context.WithTimeout(ctx, commandTimeout)
		defer cancel()
		output, err := exec.CommandContext(ctx, path, args...).CombinedOutput()
		if ctx.Err() != nil {
			return "", fmt.Errorf("ddcutil %s timed out", strings.Join(args, " "))
		}
		if err != nil {
			message := strings.TrimSpace(string(output))
			if message == "" {
				message = err.Error()
			}
			return "", fmt.Errorf("ddcutil %s: %s", strings.Join(args, " "), message)
		}
		return string(output), nil
	}, nil
}

// UnavailableRunner fails every invocation with the given error, used when
// ddcutil is missing so the capability degrades instead of erroring loudly.
func UnavailableRunner(err error) Runner {
	return func(context.Context, ...string) (string, error) {
		return "", err
	}
}

type Service struct {
	runner    Runner
	sysfsRoot string
	cache     Cache
}

func NewService(runner Runner, sysfsRoot string, cache Cache) Service {
	return Service{runner: runner, sysfsRoot: sysfsRoot, cache: cache}
}

// Discover returns the DDC-capable displays, reusing the cache while the
// sysfs connector-to-bus mapping still matches it.
func (service Service) Discover(ctx context.Context) Result {
	displays, err := service.resolve(ctx)
	return result(displays, err)
}

// Set applies a 0-100 brightness to one connector or, when connector is
// "all", to every display. A failed write triggers one fresh probe and
// retry, since i2c bus numbers drift across hotplug and reboots.
func (service Service) Set(ctx context.Context, connector string, value int) Result {
	value = writeClamp(value)
	displays, err := service.resolve(ctx)
	if err != nil && len(displays) == 0 {
		return result(nil, err)
	}

	targets := make([]Display, 0, len(displays))
	for _, candidate := range displays {
		if connector == "all" || connector == candidate.Connector {
			targets = append(targets, candidate)
		}
	}
	if len(targets) == 0 {
		return result(nil, fmt.Errorf("no DDC display for connector %q", connector))
	}

	applied := make([]Display, len(targets))
	copy(applied, targets)
	var failure error
	written := 0
	for index, target := range targets {
		updated, err := service.writeWithRetry(ctx, target, value)
		if err != nil {
			if failure == nil {
				failure = err
			}
			continue
		}
		applied[index] = updated
		written++
	}
	if written == 0 {
		return result(nil, failure)
	}

	merged := mergeDisplays(displays, applied)
	if saveErr := service.cache.Save(merged); saveErr != nil {
		failure = errors.Join(failure, fmt.Errorf("cache displays: %w", saveErr))
	}
	return result(merged, failure)
}

// writeWithRetry writes the value once, then re-probes and writes again on
// failure since a stale bus number is the usual cause.
func (service Service) writeWithRetry(ctx context.Context, target Display, value int) (Display, error) {
	if err := service.write(ctx, target, value); err == nil {
		target.Brightness = value
		return target, nil
	}
	displays, err := service.probeFresh(ctx)
	if err != nil {
		return Display{}, fmt.Errorf("%s: %w", target.Connector, err)
	}
	for _, refreshed := range displays {
		if refreshed.Connector != target.Connector {
			continue
		}
		if err := service.write(ctx, refreshed, value); err != nil {
			return Display{}, fmt.Errorf("%s: %w", refreshed.Connector, err)
		}
		refreshed.Brightness = value
		return refreshed, nil
	}
	return Display{}, fmt.Errorf("%s: display no longer present", target.Connector)
}

// mergeDisplays overlays applied entries, which may carry new bus numbers
// after a retry, onto the full list so untouched displays survive a
// single-connector write.
func mergeDisplays(displays []Display, applied []Display) []Display {
	merged := make([]Display, len(displays))
	copy(merged, displays)
	for _, item := range applied {
		for index, existing := range merged {
			if existing.Connector == item.Connector {
				merged[index] = item
				break
			}
		}
	}
	return merged
}

// resolve returns the known displays, probing and refreshing the cache only
// when the sysfs mapping no longer matches what was cached.
func (service Service) resolve(ctx context.Context) ([]Display, error) {
	mapping, err := sysfsConnectors(service.sysfsRoot)
	if err != nil {
		return nil, fmt.Errorf("read connectors: %w", err)
	}
	if cached, cacheErr := service.cache.Load(); cacheErr == nil && matchesMapping(cached, mapping) {
		return cached, nil
	}
	displays, probeErr := service.probeFresh(ctx)
	if probeErr != nil && len(displays) == 0 {
		return nil, probeErr
	}
	return displays, probeErr
}

// probeFresh probes every connected connector and replaces the cache.
func (service Service) probeFresh(ctx context.Context) ([]Display, error) {
	mapping, err := sysfsConnectors(service.sysfsRoot)
	if err != nil {
		return nil, fmt.Errorf("read connectors: %w", err)
	}
	displays, probeErr := service.probe(ctx, mapping)
	if len(displays) > 0 {
		if saveErr := service.cache.Save(displays); saveErr != nil {
			probeErr = errors.Join(probeErr, fmt.Errorf("cache displays: %w", saveErr))
		}
	}
	return displays, probeErr
}

type connectorMapping struct {
	name string
	bus  int
}

var connectorPattern = regexp.MustCompile(`^card\d+-(.+)$`)

// sysfsConnectors lists connected DRM connectors that expose a ddc i2c
// adapter, sorted by connector name.
func sysfsConnectors(root string) ([]connectorMapping, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}

	var mapping []connectorMapping
	for _, entry := range entries {
		name := connectorPattern.FindStringSubmatch(entry.Name())
		if name == nil {
			continue
		}
		status, err := os.ReadFile(filepath.Join(root, entry.Name(), "status"))
		if err != nil || strings.TrimSpace(string(status)) != "connected" {
			continue
		}
		link, err := os.Readlink(filepath.Join(root, entry.Name(), "ddc"))
		if err != nil {
			continue
		}
		bus, err := strconv.Atoi(strings.TrimPrefix(filepath.Base(link), "i2c-"))
		if err != nil {
			continue
		}
		mapping = append(mapping, connectorMapping{name: name[1], bus: bus})
	}
	sort.Slice(mapping, func(first, second int) bool {
		return mapping[first].name < mapping[second].name
	})
	return mapping, nil
}

func matchesMapping(displays []Display, mapping []connectorMapping) bool {
	if len(displays) != len(mapping) {
		return false
	}
	buses := make(map[string]int, len(displays))
	for _, item := range displays {
		buses[item.Connector] = item.Bus
	}
	for _, mapped := range mapping {
		if buses[mapped.name] != mapped.bus {
			return false
		}
	}
	return true
}

// probe reads the luminance of every mapped connector in parallel. Buses are
// independent adapters, and ddcutil failures on one connector (a monitor
// without DDC/CI, a busy bus) must not sink the others.
func (service Service) probe(ctx context.Context, mapping []connectorMapping) ([]Display, error) {
	type reading struct {
		display Display
		err     error
	}
	readings := make([]reading, len(mapping))
	var group sync.WaitGroup
	for index, mapped := range mapping {
		group.Add(1)
		go func() {
			defer group.Done()
			value, max, err := service.readLuminance(ctx, mapped.bus)
			if err != nil {
				readings[index] = reading{err: fmt.Errorf("%s: %w", mapped.name, err)}
				return
			}
			readings[index] = reading{display: Display{
				Connector:  mapped.name,
				Bus:        mapped.bus,
				Brightness: percent(value, max),
				Max:        max,
			}}
		}()
	}
	group.Wait()

	var displays []Display
	var failure error
	for _, reading := range readings {
		if reading.err != nil {
			if errors.Is(reading.err, ErrUnavailable) {
				return nil, reading.err
			}
			if failure == nil {
				failure = reading.err
			}
			continue
		}
		displays = append(displays, reading.display)
	}
	return displays, failure
}

func (service Service) readLuminance(ctx context.Context, bus int) (int, int, error) {
	output, err := service.runner(ctx, "--bus", strconv.Itoa(bus), "--skip-ddc-checks", "getvcp", "10", "--brief")
	if err != nil {
		return 0, 0, err
	}
	fields := strings.Fields(output)
	if len(fields) < 5 || fields[0] != "VCP" || fields[2] != "C" {
		return 0, 0, fmt.Errorf("parse luminance: %q", strings.TrimSpace(output))
	}
	value, valueErr := strconv.Atoi(fields[3])
	max, maxErr := strconv.Atoi(fields[4])
	if valueErr != nil || maxErr != nil || max <= 0 {
		return 0, 0, fmt.Errorf("parse luminance: %q", strings.TrimSpace(output))
	}
	return value, max, nil
}

func (service Service) write(ctx context.Context, target Display, value int) error {
	scaled := scale(value, target.Max)
	_, err := service.runner(
		ctx,
		"--bus", strconv.Itoa(target.Bus),
		"--skip-ddc-checks",
		"--noverify",
		"setvcp", "10", strconv.Itoa(scaled),
	)
	return err
}

// percent normalizes a raw VCP reading to 0-100, rounding to nearest.
func percent(value int, max int) int {
	if max <= 0 || max == 100 {
		return clamp(value)
	}
	return clamp((value*100 + max/2) / max)
}

// scale converts a 0-100 percentage to a monitor's raw range, rounding to
// nearest. Brightness floors at 1% so a write can never blank the panel.
func scale(value int, max int) int {
	value = writeClamp(value)
	if max <= 0 || max == 100 {
		return value
	}
	scaled := (value*max + 50) / 100
	if scaled > max {
		scaled = max
	}
	if scaled < 1 {
		scaled = 1
	}
	return scaled
}

func clamp(value int) int {
	if value < 0 {
		return 0
	}
	if value > 100 {
		return 100
	}
	return value
}

func writeClamp(value int) int {
	if value < 1 {
		return 1
	}
	if value > 100 {
		return 100
	}
	return value
}

func result(displays []Display, err error) Result {
	if displays == nil {
		displays = []Display{}
	}
	if err == nil {
		return Result{State: Ready, Displays: displays}
	}
	if len(displays) == 0 {
		return Result{State: Unavailable, Error: err.Error()}
	}
	return Result{State: Ready, Displays: displays, Error: err.Error()}
}
