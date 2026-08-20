package weather

import (
	"context"
	"fmt"
	"time"

	"github.com/godbus/dbus/v5"
)

const (
	geoClueBusName           = "org.freedesktop.GeoClue2"
	geoClueManagerPath       = dbus.ObjectPath("/org/freedesktop/GeoClue2/Manager")
	geoClueManagerInterface  = "org.freedesktop.GeoClue2.Manager"
	geoClueClientInterface   = "org.freedesktop.GeoClue2.Client"
	geoClueLocationInterface = "org.freedesktop.GeoClue2.Location"
	geoClueCityAccuracy      = uint32(4)
)

type GeoClue struct {
	desktopID string
	timeout   time.Duration
}

func NewGeoClue(desktopID string, timeout time.Duration) GeoClue {
	return GeoClue{desktopID: desktopID, timeout: timeout}
}

func (geoClue GeoClue) Locate(ctx context.Context) (Location, error) {
	ctx, cancel := context.WithTimeout(ctx, geoClue.timeout)
	defer cancel()

	connection, err := dbus.ConnectSystemBus()
	if err != nil {
		return Location{}, fmt.Errorf("connect to system D-Bus: %w", err)
	}
	defer connection.Close()

	manager := connection.Object(geoClueBusName, geoClueManagerPath)
	var clientPath dbus.ObjectPath
	if err := manager.CallWithContext(
		ctx,
		geoClueManagerInterface+".GetClient",
		0,
	).Store(&clientPath); err != nil {
		return Location{}, fmt.Errorf("create GeoClue client: %w", err)
	}

	client := connection.Object(geoClueBusName, clientPath)
	if err := setProperty(ctx, client, geoClueClientInterface, "DesktopId", geoClue.desktopID); err != nil {
		return Location{}, fmt.Errorf("set GeoClue desktop ID: %w", err)
	}
	if err := setProperty(
		ctx,
		client,
		geoClueClientInterface,
		"RequestedAccuracyLevel",
		geoClueCityAccuracy,
	); err != nil {
		return Location{}, fmt.Errorf("request city-level GeoClue accuracy: %w", err)
	}
	if call := client.CallWithContext(ctx, geoClueClientInterface+".Start", 0); call.Err != nil {
		return Location{}, fmt.Errorf("start GeoClue acquisition: %w", call.Err)
	}
	defer client.Call(geoClueClientInterface+".Stop", 0)

	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()
	for {
		locationPath, locationErr := objectPathProperty(
			ctx,
			client,
			geoClueClientInterface,
			"Location",
		)
		if locationErr == nil && locationPath.IsValid() && locationPath != "/" {
			return readLocation(ctx, connection.Object(geoClueBusName, locationPath))
		}

		select {
		case <-ctx.Done():
			return Location{}, fmt.Errorf("wait for GeoClue location: %w", ctx.Err())
		case <-ticker.C:
		}
	}
}

func readLocation(ctx context.Context, object dbus.BusObject) (Location, error) {
	latitude, err := floatProperty(ctx, object, geoClueLocationInterface, "Latitude")
	if err != nil {
		return Location{}, fmt.Errorf("read GeoClue latitude: %w", err)
	}
	longitude, err := floatProperty(ctx, object, geoClueLocationInterface, "Longitude")
	if err != nil {
		return Location{}, fmt.Errorf("read GeoClue longitude: %w", err)
	}
	return Location{Latitude: latitude, Longitude: longitude}, nil
}

func setProperty(
	ctx context.Context,
	object dbus.BusObject,
	objectInterface string,
	name string,
	value any,
) error {
	return object.CallWithContext(
		ctx,
		"org.freedesktop.DBus.Properties.Set",
		0,
		objectInterface,
		name,
		dbus.MakeVariant(value),
	).Err
}

func objectPathProperty(
	ctx context.Context,
	object dbus.BusObject,
	objectInterface string,
	name string,
) (dbus.ObjectPath, error) {
	variant, err := property(ctx, object, objectInterface, name)
	if err != nil {
		return "", err
	}
	value, ok := variant.Value().(dbus.ObjectPath)
	if !ok {
		return "", fmt.Errorf("property %s is not an object path", name)
	}
	return value, nil
}

func floatProperty(
	ctx context.Context,
	object dbus.BusObject,
	objectInterface string,
	name string,
) (float64, error) {
	variant, err := property(ctx, object, objectInterface, name)
	if err != nil {
		return 0, err
	}
	value, ok := variant.Value().(float64)
	if !ok {
		return 0, fmt.Errorf("property %s is not a number", name)
	}
	return value, nil
}

func property(
	ctx context.Context,
	object dbus.BusObject,
	objectInterface string,
	name string,
) (dbus.Variant, error) {
	var variant dbus.Variant
	err := object.CallWithContext(
		ctx,
		"org.freedesktop.DBus.Properties.Get",
		0,
		objectInterface,
		name,
	).Store(&variant)
	return variant, err
}
