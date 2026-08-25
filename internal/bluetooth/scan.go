package bluetooth

import (
	"context"
	"fmt"

	"github.com/godbus/dbus/v5"
)

type discoverySession interface {
	Start(context.Context) error
	Close()
}

type blueZDiscoverySession struct {
	connection *dbus.Conn
	adapter    dbus.BusObject
}

// RunScan owns a BlueZ discovery session until the context ends. BlueZ ties
// discovery to the D-Bus client, so the connection must stay open while the
// control-center scan is active.
func RunScan(ctx context.Context) error {
	session, err := newBlueZDiscoverySession(ctx)
	if err != nil {
		return err
	}
	return runDiscovery(ctx, session)
}

func newBlueZDiscoverySession(ctx context.Context) (discoverySession, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, err
	}

	path, err := adapterPath(ctx, conn)
	if err != nil {
		conn.Close()
		return nil, err
	}
	return &blueZDiscoverySession{
		connection: conn,
		adapter:    conn.Object(bluezName, path),
	}, nil
}

func runDiscovery(ctx context.Context, session discoverySession) error {
	defer session.Close()
	if err := session.Start(ctx); err != nil {
		return fmt.Errorf("start discovery: %w", err)
	}
	<-ctx.Done()
	return nil
}

func (session *blueZDiscoverySession) Start(ctx context.Context) error {
	return session.adapter.CallWithContext(
		ctx, adapterFace+".StartDiscovery", 0).Err
}

func (session *blueZDiscoverySession) Close() {
	session.connection.Close()
}
