package network

import (
	"testing"

	"github.com/godbus/dbus/v5"
)

func TestWirelessDetailsUsesManagedObjectSnapshot(t *testing.T) {
	accessPath := dbus.ObjectPath("/org/freedesktop/NetworkManager/AccessPoint/1")
	wireless := map[string]dbus.Variant{
		"AccessPoints":      dbus.MakeVariant([]dbus.ObjectPath{accessPath}),
		"ActiveAccessPoint": dbus.MakeVariant(accessPath),
	}
	all := objects{
		accessPath: {
			nmName + ".AccessPoint": {
				"Ssid":     dbus.MakeVariant([]byte("Home")),
				"Strength": dbus.MakeVariant(byte(75)),
			},
		},
	}
	device := Device{}

	wirelessDetails(wireless, all, &device)

	if len(device.AccessPoints) != 1 || device.AccessPoints[0].Ssid != "Home" {
		t.Fatalf("access points = %#v", device.AccessPoints)
	}
	if device.Active.Ssid != "Home" {
		t.Fatalf("active access point = %#v", device.Active)
	}
}
