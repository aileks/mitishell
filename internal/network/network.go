package network

import (
	"context"
	"fmt"
	"sort"

	"github.com/godbus/dbus/v5"
)

// Wi-Fi and Ethernet status over NetworkManager. The caller owns the DBus
// surface; the service normalizes it into the snapshot the network page
// renders and builds connection settings for joining.

const (
	DeviceEthernet = 1
	DeviceWifi     = 2
)

type Security string

const (
	SecurityOpen       Security = "open"
	SecurityWpa2       Security = "wpa2"
	SecurityWpa3       Security = "wpa3"
	SecurityWep        Security = "wep"
	SecurityEnterprise Security = "enterprise"
	SecurityUnknown    Security = "unknown"
)

type AccessPoint struct {
	Ssid     string
	Signal   int
	Security Security
}

type Device struct {
	Type         int
	State        uint32
	Active       AccessPoint
	AccessPoints []AccessPoint
}

type Saved struct {
	Id     string `json:"id"`
	Ssid   string `json:"ssid"`
	Hidden bool   `json:"hidden"`
}

// Caller is the NetworkManager boundary.
type Caller interface {
	WirelessEnabled(ctx context.Context) (bool, error)
	SetWirelessEnabled(ctx context.Context, enabled bool) error
	Devices(ctx context.Context) ([]Device, error)
	Saved(ctx context.Context) ([]Saved, error)
	Connect(ctx context.Context, settings map[string]map[string]dbus.Variant) error
	Forget(ctx context.Context, id string) error
}

type Station struct {
	Ssid     string   `json:"ssid"`
	Signal   int      `json:"signal"`
	Security Security `json:"security"`
	InUse    bool     `json:"inUse"`
	Saved    bool     `json:"saved"`
}

type Wifi struct {
	Available bool      `json:"available"`
	Enabled   bool      `json:"enabled"`
	State     string    `json:"state"`
	Stations  []Station `json:"stations"`
	Saved     []Saved   `json:"saved"`
}

type Ethernet struct {
	Available  bool   `json:"available"`
	State      string `json:"state"`
	Connection string `json:"connection"`
}

type Snapshot struct {
	Wifi     Wifi     `json:"wifi"`
	Ethernet Ethernet `json:"ethernet"`
	Error    string   `json:"error,omitempty"`
}

type Service struct {
	caller Caller
}

func NewService(caller Caller) Service {
	return Service{caller: caller}
}

func (service Service) Snapshot(ctx context.Context) Snapshot {
	enabled, enabledErr := service.caller.WirelessEnabled(ctx)
	if enabledErr != nil {
		return Snapshot{Error: fmt.Sprintf("read Wi-Fi state: %v", enabledErr)}
	}
	devices, err := service.caller.Devices(ctx)
	if err != nil {
		return Snapshot{Error: fmt.Sprintf("read devices: %v", err)}
	}
	saved, savedErr := service.caller.Saved(ctx)
	if savedErr != nil {
		saved = nil
	}

	snapshot := Snapshot{}
	for _, device := range devices {
		switch device.Type {
		case DeviceWifi:
			snapshot.Wifi = Wifi{
				Available: true,
				Enabled:   enabled,
				State:     deviceState(device.State),
				Stations:  stations(device, saved),
				Saved:     saved,
			}
		case DeviceEthernet:
			// Prefer the connected device when several report.
			state := deviceState(device.State)
			if !snapshot.Ethernet.Available || state == "connected" {
				snapshot.Ethernet = Ethernet{Available: true, State: state}
			}
		}
	}
	return snapshot
}

func (service Service) SetWifiEnabled(ctx context.Context, enabled bool) error {
	return service.caller.SetWirelessEnabled(ctx, enabled)
}

func (service Service) Connect(ctx context.Context, ssid string, password string, hidden bool) error {
	for _, device := range service.mustDevices(ctx) {
		if device.Type != DeviceWifi {
			continue
		}
		settings, err := connectionSettings(ssid, password, hidden, device)
		if err != nil {
			return err
		}
		return service.caller.Connect(ctx, settings)
	}
	return fmt.Errorf("no Wi-Fi device")
}

func (service Service) Forget(ctx context.Context, ssid string) error {
	for _, entry := range service.mustSaved(ctx) {
		if entry.Ssid == ssid {
			return service.caller.Forget(ctx, entry.Id)
		}
	}
	return fmt.Errorf("no saved network %q", ssid)
}

func (service Service) mustDevices(ctx context.Context) []Device {
	devices, err := service.caller.Devices(ctx)
	if err != nil {
		return nil
	}
	return devices
}

func (service Service) mustSaved(ctx context.Context) []Saved {
	saved, err := service.caller.Saved(ctx)
	if err != nil {
		return nil
	}
	return saved
}

// stations dedupes access points by ssid (strongest wins), marks saved
// networks, and sorts in-use first, then by signal.
func stations(device Device, saved []Saved) []Station {
	savedBySsid := map[string]bool{}
	for _, entry := range saved {
		savedBySsid[entry.Ssid] = true
	}

	strongest := map[string]AccessPoint{}
	inUse := map[string]bool{}
	if device.Active.Ssid != "" {
		strongest[device.Active.Ssid] = device.Active
		inUse[device.Active.Ssid] = true
	}
	for _, point := range device.AccessPoints {
		if point.Ssid == "" {
			continue
		}
		existing, ok := strongest[point.Ssid]
		if !inUse[point.Ssid] && (!ok || point.Signal > existing.Signal) {
			strongest[point.Ssid] = point
		}
	}

	list := make([]Station, 0, len(strongest))
	for ssid, point := range strongest {
		list = append(list, Station{
			Ssid:     ssid,
			Signal:   point.Signal,
			Security: point.Security,
			InUse:    inUse[ssid],
			Saved:    savedBySsid[ssid],
		})
	}
	sort.SliceStable(list, func(first, second int) bool {
		if list[first].InUse != list[second].InUse {
			return list[first].InUse
		}
		return list[first].Signal > list[second].Signal
	})
	return list
}

// deviceState maps NetworkManager device states to page vocabulary.
func deviceState(state uint32) string {
	switch state {
	case 100:
		return "connected"
	case 120:
		return "failed"
	case 40, 50, 60, 70, 80, 90:
		return "connecting"
	case 30:
		return "disconnected"
	}
	return "unavailable"
}

// connectionSettings builds an infrastructure Wi-Fi profile. The key
// management follows what the access point advertises: SAE for WPA3
// networks, WPA-PSK otherwise, and no security section for open networks.
func connectionSettings(ssid string, password string, hidden bool, device Device) (map[string]map[string]dbus.Variant, error) {
	if ssid == "" {
		return nil, fmt.Errorf("network name is required")
	}

	security := SecurityOpen
	for _, point := range device.AccessPoints {
		if point.Ssid == ssid {
			security = point.Security
			break
		}
	}

	settings := map[string]map[string]dbus.Variant{
		"connection": {
			"id":   dbus.MakeVariant(ssid),
			"type": dbus.MakeVariant("802-11-wireless"),
		},
		"802-11-wireless": {
			"ssid":   dbus.MakeVariant([]byte(ssid)),
			"mode":   dbus.MakeVariant("infrastructure"),
			"hidden": dbus.MakeVariant(hidden),
		},
		"ipv4": {"method": dbus.MakeVariant("auto")},
		"ipv6": {"method": dbus.MakeVariant("auto")},
	}

	switch security {
	case SecurityOpen:
		return settings, nil
	case SecurityEnterprise:
		return nil, fmt.Errorf("network %q needs enterprise sign-in, which mitishell does not support", ssid)
	case SecurityWpa3:
		if password == "" {
			return nil, fmt.Errorf("network %q needs a password", ssid)
		}
		settings["802-11-wireless-security"] = map[string]dbus.Variant{
			"key-mgmt": dbus.MakeVariant("sae"),
			"psk":      dbus.MakeVariant(password),
		}
	default:
		if password == "" {
			return nil, fmt.Errorf("network %q needs a password", ssid)
		}
		settings["802-11-wireless-security"] = map[string]dbus.Variant{
			"key-mgmt": dbus.MakeVariant("wpa-psk"),
			"psk":      dbus.MakeVariant(password),
		}
	}
	return settings, nil
}
