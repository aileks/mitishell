package bluetooth_test

import (
	"context"
	"errors"
	"testing"

	"github.com/aileks/mitishell/internal/bluetooth"
)

type callerStub struct {
	adapter   bluetooth.Adapter
	devices   []bluetooth.Device
	paired    []string
	connected []string
	trusted   [][2]any
	removed   []string
	err       error
}

func (stub *callerStub) Snapshot(context.Context) (bluetooth.Adapter, []bluetooth.Device, error) {
	return stub.adapter, stub.devices, stub.err
}

func (stub *callerStub) Pair(_ context.Context, address string) error {
	stub.paired = append(stub.paired, address)
	return stub.err
}

func (stub *callerStub) Connect(_ context.Context, address string) error {
	stub.connected = append(stub.connected, address)
	return stub.err
}

func (stub *callerStub) Disconnect(_ context.Context, address string) error {
	stub.connected = append(stub.connected, address)
	return stub.err
}

func (stub *callerStub) SetTrusted(_ context.Context, address string, trusted bool) error {
	stub.trusted = append(stub.trusted, [2]any{address, trusted})
	return stub.err
}

func (stub *callerStub) Remove(_ context.Context, address string) error {
	stub.removed = append(stub.removed, address)
	return stub.err
}

func TestSnapshotOrdersDevicesByUsefulness(t *testing.T) {
	stub := &callerStub{
		adapter: bluetooth.Adapter{Address: "AA:BB:CC:DD:EE:FF", Powered: true},
		devices: []bluetooth.Device{
			{Address: "11:11:11:11:11:11", Name: "Mouse", Paired: true},
			{Address: "22:22:22:22:22:22", Name: "Phone", Connected: true, Paired: true},
			{Address: "33:33:33:33:33:33", Name: "Neighbor"},
		},
	}

	snapshot := bluetooth.NewService(stub).Snapshot(context.Background())

	if !snapshot.Available || snapshot.Adapter.Address != "AA:BB:CC:DD:EE:FF" {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	ordered := []string{}
	for _, device := range snapshot.Devices {
		ordered = append(ordered, device.Name)
	}
	if len(ordered) != 3 || ordered[0] != "Phone" || ordered[1] != "Mouse" || ordered[2] != "Neighbor" {
		t.Fatalf("order = %v", ordered)
	}
}

func TestSnapshotReportsFailures(t *testing.T) {
	stub := &callerStub{err: errors.New("bluetoothd down")}
	snapshot := bluetooth.NewService(stub).Snapshot(context.Background())
	if snapshot.Available || snapshot.Error == "" {
		t.Fatalf("snapshot = %#v", snapshot)
	}
}

func TestActionsValidateAddresses(t *testing.T) {
	stub := &callerStub{}
	service := bluetooth.NewService(stub)

	if err := service.Pair(context.Background(), "not-an-address"); err == nil {
		t.Fatal("Pair accepted a malformed address")
	}
	if err := service.Connect(context.Background(), "AA:BB:CC:DD:EE"); err == nil {
		t.Fatal("Connect accepted a short address")
	}
	if len(stub.paired) != 0 || len(stub.connected) != 0 {
		t.Fatal("invalid calls reached BlueZ")
	}

	if err := service.Pair(context.Background(), "AA:BB:CC:DD:EE:FF"); err != nil {
		t.Fatalf("Pair() error = %v", err)
	}
	if err := service.SetTrusted(context.Background(), "AA:BB:CC:DD:EE:FF", false); err != nil {
		t.Fatalf("SetTrusted() error = %v", err)
	}
	if len(stub.paired) != 1 || len(stub.connected) != 1 || len(stub.trusted) != 2 || stub.trusted[1][1] != false {
		t.Fatalf("stubs = %#v %#v", stub.paired, stub.trusted)
	}
}

func TestPairCompletesUsableConnection(t *testing.T) {
	stub := &callerStub{}
	service := bluetooth.NewService(stub)
	address := "AA:BB:CC:DD:EE:FF"

	if err := service.Pair(context.Background(), address); err != nil {
		t.Fatalf("Pair() error = %v", err)
	}
	if len(stub.paired) != 1 || stub.paired[0] != address {
		t.Fatalf("paired = %v", stub.paired)
	}
	if len(stub.trusted) != 1 || stub.trusted[0] != [2]any{address, true} {
		t.Fatalf("trusted = %v", stub.trusted)
	}
	if len(stub.connected) != 1 || stub.connected[0] != address {
		t.Fatalf("connected = %v", stub.connected)
	}
}
