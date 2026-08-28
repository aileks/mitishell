// Package systemmetrics reads host metrics that need platform-aware discovery.
package systemmetrics

import (
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type Temperature struct {
	Available bool    `json:"available"`
	Celsius   float64 `json:"celsius,omitempty"`
	Sensor    string  `json:"sensor,omitempty"`
}

type TemperatureService struct {
	hwmonPath   string
	thermalPath string
}

func NewTemperatureService(hwmonPath string, thermalPath string) TemperatureService {
	return TemperatureService{hwmonPath: hwmonPath, thermalPath: thermalPath}
}

func (service TemperatureService) Snapshot() Temperature {
	if result, found := service.readHwmon(); found {
		return result
	}
	if result, found := service.readThermalZones(); found {
		return result
	}
	return Temperature{}
}

type candidate struct {
	chipRank  int
	labelRank int
	path      string
	sensor    string
}

func (service TemperatureService) readHwmon() (Temperature, bool) {
	directories, err := filepath.Glob(filepath.Join(service.hwmonPath, "hwmon*"))
	if err != nil {
		return Temperature{}, false
	}
	candidates := make([]candidate, 0)
	for _, directory := range directories {
		chip := readText(filepath.Join(directory, "name"))
		chipRank, supported := cpuChipRank(chip)
		if !supported {
			continue
		}
		inputs, _ := filepath.Glob(filepath.Join(directory, "temp*_input"))
		for _, input := range inputs {
			label := readText(strings.TrimSuffix(input, "_input") + "_label")
			candidates = append(candidates, candidate{
				chipRank:  chipRank,
				labelRank: temperatureLabelRank(label),
				path:      input,
				sensor:    strings.TrimSpace(chip + " " + label),
			})
		}
	}
	sort.Slice(candidates, func(left int, right int) bool {
		if candidates[left].chipRank != candidates[right].chipRank {
			return candidates[left].chipRank < candidates[right].chipRank
		}
		if candidates[left].labelRank != candidates[right].labelRank {
			return candidates[left].labelRank < candidates[right].labelRank
		}
		return candidates[left].path < candidates[right].path
	})
	for _, sensor := range candidates {
		if celsius, valid := readMillidegrees(sensor.path); valid {
			return Temperature{Available: true, Celsius: celsius, Sensor: sensor.sensor}, true
		}
	}
	return Temperature{}, false
}

func (service TemperatureService) readThermalZones() (Temperature, bool) {
	directories, err := filepath.Glob(filepath.Join(service.thermalPath, "thermal_zone*"))
	if err != nil {
		return Temperature{}, false
	}
	for _, directory := range directories {
		zoneType := readText(filepath.Join(directory, "type"))
		if !isCPUThermalZone(zoneType) {
			continue
		}
		if celsius, valid := readMillidegrees(filepath.Join(directory, "temp")); valid {
			return Temperature{Available: true, Celsius: celsius, Sensor: zoneType}, true
		}
	}
	return Temperature{}, false
}

func cpuChipRank(name string) (int, bool) {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "k10temp", "zenpower":
		return 0, true
	case "coretemp":
		return 1, true
	case "cpu_thermal":
		return 2, true
	default:
		return 0, false
	}
}

func temperatureLabelRank(label string) int {
	normalized := strings.ToLower(strings.TrimSpace(label))
	switch {
	case normalized == "tctl":
		return 0
	case strings.HasPrefix(normalized, "package id"):
		return 1
	case normalized == "cpu":
		return 2
	case normalized == "":
		return 4
	default:
		return 3
	}
}

func isCPUThermalZone(name string) bool {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "x86_pkg_temp", "cpu-thermal", "cpu_thermal":
		return true
	default:
		return false
	}
}

func readMillidegrees(path string) (float64, bool) {
	value, err := strconv.ParseFloat(readText(path), 64)
	if err != nil || value < 1000 || value > 200000 {
		return 0, false
	}
	return value / 1000, true
}

func readText(path string) string {
	contents, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(contents))
}
