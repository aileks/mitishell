package systemmetrics_test

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/aileks/mitishell/internal/systemmetrics"
)

func TestTemperaturePrefersCPUTctlOverUnrelatedSensors(t *testing.T) {
	root := t.TempDir()
	writeSensor(t, root, "hwmon0", "acpitz", "", "16800")
	writeSensor(t, root, "hwmon1", "nvme", "Composite", "55000")
	writeSensor(t, root, "hwmon2", "k10temp", "Tccd1", "44000")
	writeSensor(t, root, "hwmon2", "k10temp", "Tctl", "58000")

	result := service(root).Snapshot()
	if !result.Available || result.Celsius != 58 || result.Sensor != "k10temp Tctl" {
		t.Fatalf("result = %#v", result)
	}
}

func TestTemperatureUsesIntelPackageSensor(t *testing.T) {
	root := t.TempDir()
	writeSensor(t, root, "hwmon0", "coretemp", "Core 0", "49000")
	writeSensor(t, root, "hwmon0", "coretemp", "Package id 0", "53000")

	result := service(root).Snapshot()
	if !result.Available || result.Celsius != 53 || result.Sensor != "coretemp Package id 0" {
		t.Fatalf("result = %#v", result)
	}
}

func TestTemperatureFallsBackToRecognizedCPUThermalZone(t *testing.T) {
	root := t.TempDir()
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone0", "type"), "acpitz")
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone0", "temp"), "17000")
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone1", "type"), "x86_pkg_temp")
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone1", "temp"), "47500")

	result := service(root).Snapshot()
	if !result.Available || result.Celsius != 47.5 || result.Sensor != "x86_pkg_temp" {
		t.Fatalf("result = %#v", result)
	}
}

func TestTemperatureDoesNotReportACPIThermalZoneAsCPU(t *testing.T) {
	root := t.TempDir()
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone0", "type"), "acpitz")
	writeFile(t, filepath.Join(root, "thermal", "thermal_zone0", "temp"), "16800")

	if result := service(root).Snapshot(); result.Available {
		t.Fatalf("result = %#v", result)
	}
}

func service(root string) systemmetrics.TemperatureService {
	return systemmetrics.NewTemperatureService(
		filepath.Join(root, "hwmon"),
		filepath.Join(root, "thermal"),
	)
}

func writeSensor(
	t *testing.T,
	root string,
	directory string,
	chip string,
	label string,
	value string,
) {
	t.Helper()
	sensorDirectory := filepath.Join(root, "hwmon", directory)
	namePath := filepath.Join(sensorDirectory, "name")
	if _, err := os.Stat(namePath); os.IsNotExist(err) {
		writeFile(t, namePath, chip)
	}
	inputs, _ := filepath.Glob(filepath.Join(sensorDirectory, "temp*_input"))
	index := len(inputs) + 1
	prefix := filepath.Join(sensorDirectory, "temp"+strconv.Itoa(index))
	writeFile(t, prefix+"_input", value)
	if label != "" {
		writeFile(t, prefix+"_label", label)
	}
}

func writeFile(t *testing.T, path string, contents string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}
}
