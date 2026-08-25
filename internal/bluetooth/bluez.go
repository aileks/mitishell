package bluetooth

import (
	"context"
	"fmt"
	"strings"

	"github.com/godbus/dbus/v5"
)

// BlueZ DBus constants.
const (
	bluezName          = "org.bluez"
	bluezRoot          = "/"
	adapterFace        = bluezName + ".Adapter1"
	deviceFace         = bluezName + ".Device1"
	batteryFace        = bluezName + ".Battery1"
	propertiesFace     = "org.freedesktop.DBus.Properties"
	objectManagerIface = "org.freedesktop.DBus.ObjectManager"
	controlName        = "io.github.aileks.mitishell"
	controlPath        = "/io/github/aileks/mitishell/bluetooth"
	controlFace        = controlName + ".bluetooth"
)

type bluezObjects = map[dbus.ObjectPath]map[string]map[string]dbus.Variant

// BlueZCaller is the production Caller over the system bus.
type BlueZCaller struct{}

func (caller BlueZCaller) connect(ctx context.Context) (*dbus.Conn, error) {
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

func (caller BlueZCaller) Snapshot(ctx context.Context) (Adapter, []Device, error) {
	conn, err := caller.connect(ctx)
	if err != nil {
		return Adapter{}, nil, err
	}

	all, err := bluezManagedObjects(ctx, conn)
	if err != nil {
		return Adapter{}, nil, err
	}

	adapter := Adapter{}
	var devices []Device
	for _, interfaces := range all {
		if props, ok := interfaces[adapterFace]; ok {
			adapter = Adapter{
				Address:     strings.ToUpper(propertyString(props, "Address")),
				Powered:     propertyBool(props, "Powered"),
				Discovering: propertyBool(props, "Discovering"),
			}
		}
		if props, ok := interfaces[deviceFace]; ok {
			device := Device{
				Address:   strings.ToUpper(propertyString(props, "Address")),
				Name:      propertyString(props, "Alias"),
				Paired:    propertyBool(props, "Paired"),
				Trusted:   propertyBool(props, "Trusted"),
				Connected: propertyBool(props, "Connected"),
			}
			if device.Name == "" {
				device.Name = propertyString(props, "Name")
			}
			if batteryProps, ok := interfaces[batteryFace]; ok {
				percentage := int(propertyByte(batteryProps, "Percentage"))
				device.Battery = &percentage
			}
			// Devices BlueZ still lists with signal info are in range.
			_, hasSignal := props["RSSI"]
			device.InRange = device.Connected || hasSignal
			devices = append(devices, device)
		}
	}
	if adapter.Address == "" {
		return Adapter{}, nil, fmt.Errorf("no Bluetooth adapter")
	}
	return adapter, devices, nil
}

func (caller BlueZCaller) Pair(ctx context.Context, address string) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	path, err := devicePath(ctx, conn, address)
	if err != nil {
		return err
	}
	return conn.Object(bluezName, path).CallWithContext(
		ctx, deviceFace+".Pair", 0).Err
}

func (caller BlueZCaller) Connect(ctx context.Context, address string) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	path, err := devicePath(ctx, conn, address)
	if err != nil {
		return err
	}
	return conn.Object(bluezName, path).CallWithContext(
		ctx, deviceFace+".Connect", 0).Err
}

func (caller BlueZCaller) Disconnect(ctx context.Context, address string) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	path, err := devicePath(ctx, conn, address)
	if err != nil {
		return err
	}
	return conn.Object(bluezName, path).CallWithContext(
		ctx, deviceFace+".Disconnect", 0).Err
}

func (caller BlueZCaller) SetTrusted(ctx context.Context, address string, trusted bool) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	path, err := devicePath(ctx, conn, address)
	if err != nil {
		return err
	}
	return conn.Object(bluezName, path).CallWithContext(
		ctx, propertiesFace+".Set", 0, deviceFace, "Trusted",
		dbus.MakeVariant(trusted)).Err
}

func (caller BlueZCaller) Remove(ctx context.Context, address string) error {
	conn, err := caller.connect(ctx)
	if err != nil {
		return err
	}
	adapter, err := adapterPath(ctx, conn)
	if err != nil {
		return err
	}
	device, err := devicePath(ctx, conn, address)
	if err != nil {
		return err
	}
	return conn.Object(bluezName, adapter).CallWithContext(
		ctx, adapterFace+".RemoveDevice", 0, device).Err
}

func bluezManagedObjects(ctx context.Context, conn *dbus.Conn) (bluezObjects, error) {
	manager := conn.Object(bluezName, bluezRoot)
	call := manager.CallWithContext(ctx, objectManagerIface+".GetManagedObjects", 0)
	if call.Err != nil {
		return nil, call.Err
	}
	var all bluezObjects
	if err := call.Store(&all); err != nil {
		return nil, err
	}
	return all, nil
}

func adapterPath(ctx context.Context, conn *dbus.Conn) (dbus.ObjectPath, error) {
	objects, err := bluezManagedObjects(ctx, conn)
	if err != nil {
		return "", err
	}
	for path, interfaces := range objects {
		if _, ok := interfaces[adapterFace]; ok {
			return path, nil
		}
	}
	return "", fmt.Errorf("no Bluetooth adapter")
}

func devicePath(ctx context.Context, conn *dbus.Conn, address string) (dbus.ObjectPath, error) {
	objects, err := bluezManagedObjects(ctx, conn)
	if err != nil {
		return "", err
	}
	target := strings.ToUpper(address)
	for path, interfaces := range objects {
		props, ok := interfaces[deviceFace]
		if !ok || strings.ToUpper(propertyString(props, "Address")) != target {
			continue
		}
		return path, nil
	}
	return "", fmt.Errorf("no device %q", address)
}

func propertyString(props map[string]dbus.Variant, key string) string {
	value, ok := props[key]
	if !ok {
		return ""
	}
	text, _ := value.Value().(string)
	return text
}

func propertyBool(props map[string]dbus.Variant, key string) bool {
	value, ok := props[key]
	if !ok {
		return false
	}
	flag, _ := value.Value().(bool)
	return flag
}

func propertyByte(props map[string]dbus.Variant, key string) byte {
	value, ok := props[key]
	if !ok {
		return 0
	}
	number, _ := value.Value().(byte)
	return number
}
