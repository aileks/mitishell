package power

import (
	"context"
	"fmt"

	"github.com/godbus/dbus/v5"
)

// LogindCaller is the production Caller over the system bus.
type LogindCaller struct{}

func (caller LogindCaller) manager(ctx context.Context) (dbus.BusObject, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, err
	}
	go func() {
		<-ctx.Done()
		conn.Close()
	}()
	return conn.Object(login1Name, login1Path), nil
}

func (caller LogindCaller) can(ctx context.Context, method string) (string, error) {
	object, err := caller.manager(ctx)
	if err != nil {
		return "", err
	}
	call := object.CallWithContext(ctx, login1Manager+"."+method, 0)
	if call.Err != nil {
		return "", call.Err
	}
	var reply string
	if err := call.Store(&reply); err != nil {
		return "", err
	}
	return reply, nil
}

func (caller LogindCaller) act(ctx context.Context, method string) error {
	object, err := caller.manager(ctx)
	if err != nil {
		return err
	}
	// The boolean argument asks logind to authenticate interactively when
	// polkit requires it, matching loginctl behavior.
	call := object.CallWithContext(ctx, login1Manager+"."+method, 0, true)
	if call.Err != nil {
		return call.Err
	}
	return nil
}

func (caller LogindCaller) CanSuspend(ctx context.Context) (string, error) {
	return caller.can(ctx, "CanSuspend")
}

func (caller LogindCaller) CanHibernate(ctx context.Context) (string, error) {
	return caller.can(ctx, "CanHibernate")
}

func (caller LogindCaller) Suspend(ctx context.Context) error {
	return caller.act(ctx, "Suspend")
}

func (caller LogindCaller) Hibernate(ctx context.Context) error {
	return caller.act(ctx, "Hibernate")
}

func (caller LogindCaller) Reboot(ctx context.Context) error {
	return caller.act(ctx, "Reboot")
}

func (caller LogindCaller) PowerOff(ctx context.Context) error {
	return caller.act(ctx, "PowerOff")
}

// LockSession emits the session's Lock signal, which idle daemons and
// session-lock clients act on.
func (caller LogindCaller) LockSession(ctx context.Context) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	path, err := sessionPath(conn)
	if err != nil {
		return err
	}
	object := conn.Object(login1Name, path)
	call := object.CallWithContext(ctx, login1Name+".Session.Lock", 0)
	if call.Err != nil {
		return call.Err
	}
	return nil
}

// sessionPath resolves the caller's session object through the login1
// manager's session cookie.
func sessionPath(conn *dbus.Conn) (dbus.ObjectPath, error) {
	object := conn.Object(login1Name, login1Path)
	call := object.Call(login1Manager+".GetSessionByPID", 0, uint32(0))
	if call.Err != nil {
		return "", call.Err
	}
	var path dbus.ObjectPath
	if err := call.Store(&path); err != nil {
		return "", err
	}
	if path == "" {
		return "", fmt.Errorf("no login1 session for this process")
	}
	return path, nil
}
