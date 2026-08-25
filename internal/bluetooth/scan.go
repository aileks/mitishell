package bluetooth

import (
	"context"
	"fmt"

	"github.com/godbus/dbus/v5"
)

// RunScan owns a BlueZ discovery session until the context ends. BlueZ ties
// discovery to the D-Bus client, so the connection must stay open while the
// control-center scan is active.
func RunScan(ctx context.Context) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	path, err := adapterPath(conn)
	if err != nil {
		return err
	}
	adapter := conn.Object(bluezName, path)
	if err := adapter.Call(adapterFace+".StartDiscovery", 0).Err; err != nil {
		return fmt.Errorf("start discovery: %w", err)
	}
	defer adapter.Call(adapterFace+".StopDiscovery", 0)

	<-ctx.Done()
	return nil
}
