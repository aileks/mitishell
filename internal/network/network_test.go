package network_test

import (
	"context"
	"errors"
	"testing"

	"github.com/godbus/dbus/v5"

	"github.com/aileks/mitishell/internal/network"
)

type callerStub struct {
	devices []network.Device
	saved   []network.Saved
	connect []map[string]map[string]dbus.Variant
	forgot  []string
	err     error
}

func (stub *callerStub) Devices(context.Context) ([]network.Device, error) {
	return stub.devices, stub.err
}

func (stub *callerStub) Saved(context.Context) ([]network.Saved, error) {
	return stub.saved, stub.err
}

func (stub *callerStub) Connect(_ context.Context, settings map[string]map[string]dbus.Variant) error {
	stub.connect = append(stub.connect, settings)
	return stub.err
}

func (stub *callerStub) Forget(_ context.Context, id string) error {
	stub.forgot = append(stub.forgot, id)
	return stub.err
}

func TestSnapshotNormalizesDevices(t *testing.T) {
	stub := &callerStub{
		devices: []network.Device{
			{
				Type:   network.DeviceWifi,
				State:  100,
				Active: network.AccessPoint{Ssid: "Home", Signal: 70, Security: network.SecurityWpa2},
				AccessPoints: []network.AccessPoint{
					{Ssid: "Home", Signal: 70, Security: network.SecurityWpa2},
					{Ssid: "Home", Signal: 40, Security: network.SecurityWpa2},
					{Ssid: "Cafe", Signal: 90, Security: network.SecurityOpen},
					{Ssid: "", Signal: 99, Security: network.SecurityOpen},
					{Ssid: "Wpa3Net", Signal: 55, Security: network.SecurityWpa3},
				},
			},
			{Type: network.DeviceEthernet, State: 100},
			{Type: network.DeviceEthernet, State: 30},
		},
		saved: []network.Saved{{Id: "Home", Ssid: "Home"}},
	}

	snapshot := network.NewService(stub).Snapshot(context.Background())

	if !snapshot.Wifi.Available || snapshot.Wifi.State != "connected" {
		t.Fatalf("wifi = %#v", snapshot.Wifi)
	}
	if snapshot.Ethernet.State != "connected" {
		t.Fatalf("ethernet = %#v", snapshot.Ethernet)
	}

	stations := snapshot.Wifi.Stations
	if len(stations) != 3 {
		t.Fatalf("stations = %#v", stations)
	}
	if stations[0].Ssid != "Home" || !stations[0].InUse || !stations[0].Saved {
		t.Fatalf("in-use saved network should lead: %#v", stations[0])
	}
	if stations[1].Ssid != "Cafe" || stations[1].Signal != 90 {
		t.Fatalf("ordering by signal broken: %#v", stations)
	}
	if stations[2].Ssid != "Wpa3Net" {
		t.Fatalf("stations = %#v", stations)
	}
}

func TestSnapshotMapsDeviceStates(t *testing.T) {
	cases := map[uint32]string{
		100: "connected",
		120: "failed",
		50:  "connecting",
		30:  "disconnected",
		10:  "unavailable",
	}
	for state, want := range cases {
		stub := &callerStub{devices: []network.Device{{Type: network.DeviceWifi, State: state}}}
		snapshot := network.NewService(stub).Snapshot(context.Background())
		if snapshot.Wifi.State != want {
			t.Fatalf("state %d mapped to %q, want %q", state, snapshot.Wifi.State, want)
		}
	}
}

func TestSnapshotReportsFailures(t *testing.T) {
	stub := &callerStub{err: errors.New("nm unreachable")}
	snapshot := network.NewService(stub).Snapshot(context.Background())
	if snapshot.Error == "" || snapshot.Wifi.Available {
		t.Fatalf("snapshot = %#v", snapshot)
	}
}

func TestConnectBuildsSettingsForNetworks(t *testing.T) {
	cases := []struct {
		name     string
		ssid     string
		password string
		security network.Security
		keyMgmt  string
		secured  bool
	}{
		{name: "open network", ssid: "Cafe", password: "", security: network.SecurityOpen, secured: false},
		{name: "wpa2 network", ssid: "Home", password: "secret", security: network.SecurityWpa2, keyMgmt: "wpa-psk", secured: true},
		{name: "wpa3 network", ssid: "Future", password: "secret", security: network.SecurityWpa3, keyMgmt: "sae", secured: true},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			stub := &callerStub{devices: []network.Device{{
				Type: network.DeviceWifi,
				AccessPoints: []network.AccessPoint{
					{Ssid: testCase.ssid, Signal: 80, Security: testCase.security},
				},
			}}}

			err := network.NewService(stub).Connect(
				context.Background(), testCase.ssid, testCase.password, false)

			if err != nil {
				t.Fatalf("Connect() error = %v", err)
			}
			if len(stub.connect) != 1 {
				t.Fatalf("Connect() calls = %d", len(stub.connect))
			}
			settings := stub.connect[0]
			if string(settings["802-11-wireless"]["ssid"].Value().([]byte)) != testCase.ssid {
				t.Fatalf("ssid = %#v", settings)
			}
			security, hasSecurity := settings["802-11-wireless-security"]
			if testCase.secured != hasSecurity {
				t.Fatalf("security section presence = %v, want %v", hasSecurity, testCase.secured)
			}
			if hasSecurity {
				if security["key-mgmt"].Value().(string) != testCase.keyMgmt {
					t.Fatalf("key-mgmt = %#v", security)
				}
				if security["psk"].Value().(string) != testCase.password {
					t.Fatalf("psk = %#v", security)
				}
			}
		})
	}
}

func TestConnectRequiresPasswordsAndDevices(t *testing.T) {
	secured := &callerStub{devices: []network.Device{{
		Type: network.DeviceWifi,
		AccessPoints: []network.AccessPoint{
			{Ssid: "Home", Signal: 60, Security: network.SecurityWpa2},
		},
	}}}
	if err := network.NewService(secured).Connect(context.Background(), "Home", "", false); err == nil {
		t.Fatal("Connect accepted an empty password for a secured network")
	}

	empty := &callerStub{}
	if err := network.NewService(empty).Connect(context.Background(), "Home", "pw", false); err == nil {
		t.Fatal("Connect accepted joining without a Wi-Fi device")
	}

	if err := network.NewService(secured).Connect(context.Background(), "", "pw", false); err == nil {
		t.Fatal("Connect accepted an empty ssid")
	}
}

func TestForgetRemovesTheMatchingProfile(t *testing.T) {
	stub := &callerStub{saved: []network.Saved{
		{Id: "Cafe-uuid", Ssid: "Cafe"},
		{Id: "Home-uuid", Ssid: "Home"},
	}}

	if err := network.NewService(stub).Forget(context.Background(), "Home"); err != nil {
		t.Fatalf("Forget() error = %v", err)
	}
	if len(stub.forgot) != 1 || stub.forgot[0] != "Home-uuid" {
		t.Fatalf("forgot = %v", stub.forgot)
	}

	if err := network.NewService(stub).Forget(context.Background(), "Nowhere"); err == nil {
		t.Fatal("Forget accepted an unknown network")
	}
}
