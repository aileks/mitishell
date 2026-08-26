package bluetooth

import (
	"context"
	"fmt"
	"sort"
)

// Bluetooth over BlueZ. The caller owns the DBus surface; the service
// normalizes devices for the page and validates actions.

type Adapter struct {
	Address     string `json:"address"`
	Powered     bool   `json:"powered"`
	Discovering bool   `json:"discovering"`
}

type Device struct {
	Address   string `json:"address"`
	Name      string `json:"name"`
	Paired    bool   `json:"paired"`
	Trusted   bool   `json:"trusted"`
	Connected bool   `json:"connected"`
	Battery   *int   `json:"battery"`
	InRange   bool   `json:"inRange"`
}

type Snapshot struct {
	Available bool     `json:"available"`
	Adapter   Adapter  `json:"adapter"`
	Devices   []Device `json:"devices"`
	Error     string   `json:"error,omitempty"`
}

type Caller interface {
	Snapshot(ctx context.Context) (Adapter, []Device, error)
	Pair(ctx context.Context, address string) error
	Connect(ctx context.Context, address string) error
	Disconnect(ctx context.Context, address string) error
	SetTrusted(ctx context.Context, address string, trusted bool) error
	Remove(ctx context.Context, address string) error
}

type Service struct {
	caller Caller
}

func NewService(caller Caller) Service {
	return Service{caller: caller}
}

func (service Service) Snapshot(ctx context.Context) Snapshot {
	adapter, devices, err := service.caller.Snapshot(ctx)
	if err != nil {
		return Snapshot{Error: fmt.Sprintf("read devices: %v", err)}
	}
	return Snapshot{
		Available: true,
		Adapter:   adapter,
		Devices:   ordered(devices),
	}
}

func (service Service) Pair(ctx context.Context, address string) error {
	if !validAddress(address) {
		return fmt.Errorf("no device %q", address)
	}
	if err := service.caller.Pair(ctx, address); err != nil {
		return fmt.Errorf("pair device: %w", err)
	}
	if err := service.caller.SetTrusted(ctx, address, true); err != nil {
		return fmt.Errorf("trust paired device: %w", err)
	}
	if err := service.caller.Connect(ctx, address); err != nil {
		return fmt.Errorf("connect paired device: %w", err)
	}
	return nil
}

func (service Service) Connect(ctx context.Context, address string) error {
	if !validAddress(address) {
		return fmt.Errorf("no device %q", address)
	}
	return service.caller.Connect(ctx, address)
}

func (service Service) Disconnect(ctx context.Context, address string) error {
	if !validAddress(address) {
		return fmt.Errorf("no device %q", address)
	}
	return service.caller.Disconnect(ctx, address)
}

func (service Service) SetTrusted(ctx context.Context, address string, trusted bool) error {
	if !validAddress(address) {
		return fmt.Errorf("no device %q", address)
	}
	return service.caller.SetTrusted(ctx, address, trusted)
}

func (service Service) Remove(ctx context.Context, address string) error {
	if !validAddress(address) {
		return fmt.Errorf("no device %q", address)
	}
	return service.caller.Remove(ctx, address)
}

// ordered lists connected devices first, then paired ones, then discovered.
func ordered(devices []Device) []Device {
	orderedDevices := make([]Device, len(devices))
	copy(orderedDevices, devices)
	sort.SliceStable(orderedDevices, func(first, second int) bool {
		switch {
		case orderedDevices[first].Connected != orderedDevices[second].Connected:
			return orderedDevices[first].Connected
		case orderedDevices[first].Paired != orderedDevices[second].Paired:
			return orderedDevices[first].Paired
		default:
			return orderedDevices[first].Name < orderedDevices[second].Name
		}
	})
	return orderedDevices
}

func validAddress(address string) bool {
	if len(address) != 17 {
		return false
	}
	for index, character := range address {
		if index%3 == 2 && character != ':' {
			return false
		}
	}
	return true
}
