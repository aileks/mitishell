package network

import (
	"context"
	"fmt"

	"github.com/godbus/dbus/v5"
)

// NetworkManager DBus constants.
const (
	nmName      = "org.freedesktop.NetworkManager"
	nmRoot      = "/org/freedesktop/NetworkManager"
	nmInterface = nmName
	// NetworkManager publishes its ObjectManager one level up.
	omPath = "/org/freedesktop"
	omName = "org.freedesktop.DBus.ObjectManager"
)

// NM access point security flag bits.
const (
	apPrivacy  = 0x1
	apPairWep  = 0x3
	apKeyPSK   = 0x100
	apKey8021x = 0x200
	apKeySAE   = 0x400
)

type objects = map[dbus.ObjectPath]map[string]map[string]dbus.Variant

// NMCaller is the production Caller over the system bus.
type NMCaller struct{}

func (caller NMCaller) WirelessEnabled(ctx context.Context) (bool, error) {
	conn, err := caller.connect(ctx)
	if err != nil {
		return false, err
	}
	value, err := conn.Object(nmName, nmRoot).GetProperty(nmInterface + ".WirelessEnabled")
	if err != nil {
		return false, err
	}
	enabled, ok := value.Value().(bool)
	if !ok {
		return false, fmt.Errorf("WirelessEnabled is not a boolean")
	}
	return enabled, nil
}

func (caller NMCaller) SetWirelessEnabled(ctx context.Context, enabled bool) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	return conn.Object(nmName, nmRoot).SetProperty(
		nmInterface+".WirelessEnabled", enabled)
}

func (caller NMCaller) connect(ctx context.Context) (*dbus.Conn, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, err
	}
	go func() {
		<-ctx.Done()
		conn.Close()
	}()
	return conn, nil
}

func (caller NMCaller) Devices(ctx context.Context) ([]Device, error) {
	conn, err := caller.connect(ctx)
	if err != nil {
		return nil, err
	}
	all, err := managedObjects(conn)
	if err != nil {
		return nil, err
	}

	var devices []Device
	for _, interfaces := range all {
		deviceProps, ok := interfaces[nmName+".Device"]
		if !ok {
			continue
		}
		deviceType, ok := valueUint(deviceProps, "DeviceType")
		if !ok {
			continue
		}

		device := Device{
			Type:  int(deviceType),
			State: valueUintOr(deviceProps, "State"),
		}
		if wireless, ok := interfaces[nmName+".Device.Wireless"]; ok {
			wirelessDetails(wireless, all, &device)
		}
		devices = append(devices, device)
	}
	return devices, nil
}

func wirelessDetails(
	wireless map[string]dbus.Variant,
	all objects,
	device *Device,
) {
	// Use the access-point paths from the same managed-object snapshot as
	// their properties. This avoids a second D-Bus call racing device churn.
	for _, accessPath := range valuePathsOr(wireless, "AccessPoints") {
		if props, ok := all[accessPath][nmName+".AccessPoint"]; ok {
			device.AccessPoints = append(device.AccessPoints, accessPoint(props))
		}
	}

	if activePath, ok := valuePath(wireless, "ActiveAccessPoint"); ok && activePath != "/" {
		if props, ok := all[activePath][nmName+".AccessPoint"]; ok {
			device.Active = accessPoint(props)
		}
	}
}

func (caller NMCaller) Saved(ctx context.Context) ([]Saved, error) {
	conn, err := caller.connect(ctx)
	if err != nil {
		return nil, err
	}
	var saved []Saved
	for _, path := range connectionPaths(conn) {
		if entry, ok := connectionEntry(conn, path); ok {
			saved = append(saved, entry)
		}
	}
	return saved, nil
}

func (caller NMCaller) Connect(ctx context.Context, settings map[string]map[string]dbus.Variant) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	all, err := managedObjects(conn)
	if err != nil {
		return err
	}

	ssid := string(valueBytesOr(settings["802-11-wireless"], "ssid"))
	wifiPath := dbus.ObjectPath("")
	accessPath := dbus.ObjectPath("/")
	best := -1
	for path, interfaces := range all {
		if props, ok := interfaces[nmName+".AccessPoint"]; ok {
			point := accessPoint(props)
			if point.Ssid == ssid && point.Signal > best {
				accessPath = path
				best = point.Signal
			}
		}
		deviceProps, ok := interfaces[nmName+".Device"]
		if !ok || int(valueUintOr(deviceProps, "DeviceType")) != DeviceWifi {
			continue
		}
		if wifiPath == "" {
			wifiPath = path
		}
	}
	if wifiPath == "" {
		return fmt.Errorf("no Wi-Fi device")
	}

	manager := conn.Object(nmName, nmRoot)
	call := manager.CallWithContext(ctx, nmName+".AddAndActivateConnection", 0,
		settings, wifiPath, accessPath)
	return call.Err
}

func (caller NMCaller) Forget(ctx context.Context, id string) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	for _, path := range connectionPaths(conn) {
		if entry, ok := connectionEntry(conn, path); ok && entry.Id == id {
			connection := conn.Object(nmName, path)
			return connection.CallWithContext(
				ctx, nmName+".Settings.Connection.Delete", 0).Err
		}
	}
	return fmt.Errorf("no saved network %q", id)
}

func managedObjects(conn *dbus.Conn) (objects, error) {
	manager := conn.Object(nmName, omPath)
	call := manager.Call(omName+".GetManagedObjects", 0)
	if call.Err != nil {
		return nil, call.Err
	}
	var all objects
	if err := call.Store(&all); err != nil {
		return nil, err
	}
	return all, nil
}

func connectionPaths(conn *dbus.Conn) []dbus.ObjectPath {
	settings := conn.Object(nmName, nmRoot+"/Settings")
	call := settings.Call(nmName+".Settings.ListConnections", 0)
	if call.Err != nil {
		return nil
	}
	var paths []dbus.ObjectPath
	if err := call.Store(&paths); err != nil {
		return nil
	}
	return paths
}

func connectionEntry(conn *dbus.Conn, path dbus.ObjectPath) (Saved, bool) {
	connection := conn.Object(nmName, path)
	call := connection.Call(nmName+".Settings.Connection.GetSettings", 0)
	if call.Err != nil {
		return Saved{}, false
	}
	var config map[string]map[string]dbus.Variant
	if err := call.Store(&config); err != nil {
		return Saved{}, false
	}

	connectionProps, ok := config["connection"]
	if !ok || valueStringOr(connectionProps, "type") != "802-11-wireless" {
		return Saved{}, false
	}
	wireless, ok := config["802-11-wireless"]
	if !ok {
		return Saved{}, false
	}
	return Saved{
		Id:     valueStringOr(connectionProps, "id"),
		Ssid:   string(valueBytesOr(wireless, "ssid")),
		Hidden: valueBoolOr(wireless, "hidden"),
	}, true
}

func accessPoint(props map[string]dbus.Variant) AccessPoint {
	// Strength is a byte on the wire, unlike the flag properties.
	strength, _ := props["Strength"].Value().(byte)
	return AccessPoint{
		Ssid:   string(valueBytesOr(props, "Ssid")),
		Signal: int(strength),
		Security: securityFor(valueUintOr(props, "Flags"),
			valueUintOr(props, "WpaFlags"), valueUintOr(props, "RsnFlags")),
	}
}

func securityFor(flags uint32, wpa uint32, rsn uint32) Security {
	if flags&apPrivacy == 0 {
		return SecurityOpen
	}
	if rsn&apKeySAE != 0 {
		return SecurityWpa3
	}
	if rsn&apKeyPSK != 0 || wpa&apKeyPSK != 0 {
		return SecurityWpa2
	}
	if rsn&apKey8021x != 0 || wpa&apKey8021x != 0 {
		return SecurityEnterprise
	}
	if wpa&apPairWep != 0 {
		return SecurityWep
	}
	return SecurityUnknown
}

func valueUint(props map[string]dbus.Variant, key string) (uint32, bool) {
	value, ok := props[key]
	if !ok {
		return 0, false
	}
	number, ok := value.Value().(uint32)
	return number, ok
}

func valueUintOr(props map[string]dbus.Variant, key string) uint32 {
	number, _ := valueUint(props, key)
	return number
}

func valuePath(props map[string]dbus.Variant, key string) (dbus.ObjectPath, bool) {
	value, ok := props[key]
	if !ok {
		return "", false
	}
	path, ok := value.Value().(dbus.ObjectPath)
	return path, ok
}

func valuePathsOr(props map[string]dbus.Variant, key string) []dbus.ObjectPath {
	value, ok := props[key]
	if !ok {
		return nil
	}
	paths, _ := value.Value().([]dbus.ObjectPath)
	return paths
}

func valueBytesOr(props map[string]dbus.Variant, key string) []byte {
	value, ok := props[key]
	if !ok {
		return nil
	}
	switch bytes := value.Value().(type) {
	case []byte:
		return bytes
	case []interface{}:
		raw := make([]byte, 0, len(bytes))
		for _, item := range bytes {
			if b, ok := item.(byte); ok {
				raw = append(raw, b)
			}
		}
		return raw
	}
	return nil
}

func valueStringOr(props map[string]dbus.Variant, key string) string {
	value, ok := props[key]
	if !ok {
		return ""
	}
	text, _ := value.Value().(string)
	return text
}

func valueBoolOr(props map[string]dbus.Variant, key string) bool {
	value, ok := props[key]
	if !ok {
		return false
	}
	flag, _ := value.Value().(bool)
	return flag
}
