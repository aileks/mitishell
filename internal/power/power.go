package power

import (
	"context"
	"fmt"
	"os/exec"
)

// Session power over logind. Capability queries and the logind actions run
// over the system bus; hyprshutdown owns graceful session exit.

const (
	login1Name      = "org.freedesktop.login1"
	login1Path      = "/org/freedesktop/login1"
	login1Manager   = login1Name + ".Manager"
	logindInterface = login1Name
)

type Action string

const (
	Lock      Action = "lock"
	Logout    Action = "logout"
	Suspend   Action = "suspend"
	Hibernate Action = "hibernate"
	Reboot    Action = "reboot"
	Shutdown  Action = "shutdown"
)

type Capabilities struct {
	Suspend   bool `json:"suspend"`
	Hibernate bool `json:"hibernate"`
}

// Caller is the logind boundary, injectable for tests.
type Caller interface {
	CanSuspend(ctx context.Context) (string, error)
	CanHibernate(ctx context.Context) (string, error)
	Suspend(ctx context.Context) error
	Hibernate(ctx context.Context) error
	Reboot(ctx context.Context) error
	PowerOff(ctx context.Context) error
	LockSession(ctx context.Context) error
}

type Service struct {
	caller Caller
}

func NewService(caller Caller) Service {
	return Service{caller: caller}
}

// Capabilities reports which conditional actions the system supports.
// Hibernate is only offered when logind can actually hibernate.
func (service Service) Capabilities(ctx context.Context) (Capabilities, error) {
	suspend, err := service.caller.CanSuspend(ctx)
	if err != nil {
		return Capabilities{}, fmt.Errorf("query suspend: %w", err)
	}
	hibernate, err := service.caller.CanHibernate(ctx)
	if err != nil {
		return Capabilities{}, fmt.Errorf("query hibernate: %w", err)
	}
	return Capabilities{
		Suspend:   available(suspend),
		Hibernate: available(hibernate),
	}, nil
}

// Run executes a power action. Everything except logout goes to logind.
func (service Service) Run(ctx context.Context, action Action) error {
	switch action {
	case Lock:
		return service.caller.LockSession(ctx)
	case Logout:
		return logout()
	case Suspend:
		return service.caller.Suspend(ctx)
	case Hibernate:
		return service.caller.Hibernate(ctx)
	case Reboot:
		return service.caller.Reboot(ctx)
	case Shutdown:
		return service.caller.PowerOff(ctx)
	}
	return fmt.Errorf("unknown power action %q", action)
}

func available(reply string) bool {
	return reply == "yes"
}

// logout asks hyprshutdown to close the session's apps and exit Hyprland.
// The daemon runs from a transient scope instead of this process's cgroup:
// the shell closes itself along with the other apps, and when mitishell.service
// stops, systemd would sweep the forked hyprshutdown away before it sends
// the final "dispatch exit" to Hyprland.
func logout() error {
	command := exec.Command("systemd-run", "--user", "--scope", "--collect", "hyprshutdown")
	output, err := command.CombinedOutput()
	if err != nil {
		message := string(output)
		if message == "" {
			message = err.Error()
		}
		return fmt.Errorf("hyprshutdown: %s", message)
	}
	return nil
}
