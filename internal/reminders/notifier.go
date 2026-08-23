package reminders

import (
	"context"
	"errors"
	"fmt"

	"github.com/godbus/dbus/v5"
)

var ErrNotificationServerUnavailable = errors.New("notification server unavailable")

type Notification struct {
	AppName       string
	AppIcon       string
	Summary       string
	Body          string
	Actions       []string
	Hints         map[string]dbus.Variant
	ExpireTimeout int32
}

type NotificationCaller interface {
	Notify(context.Context, Notification) error
}

type Notifier interface {
	Deliver(context.Context, Record) error
}

type DBusNotifier struct {
	caller NotificationCaller
}

func NewDBusNotifier() DBusNotifier {
	return DBusNotifier{caller: SessionNotificationCaller{}}
}

func NewDBusNotifierWithCaller(caller NotificationCaller) DBusNotifier {
	return DBusNotifier{caller: caller}
}

func (notifier DBusNotifier) Deliver(ctx context.Context, record Record) error {
	notification := Notification{
		AppName: "Mitishell",
		AppIcon: "appointment-soon",
		Summary: "Reminder",
		Body:    record.Message,
		Actions: []string{},
		Hints: map[string]dbus.Variant{
			"desktop-entry":        dbus.MakeVariant("mitishell"),
			"transient":            dbus.MakeVariant(false),
			"urgency":              dbus.MakeVariant(byte(1)),
			"x-mitishell-reminder": dbus.MakeVariant(true),
		},
		ExpireTimeout: 8000,
	}
	if err := notifier.caller.Notify(ctx, notification); err != nil {
		return fmt.Errorf("deliver reminder notification: %w", err)
	}
	return nil
}

type SessionNotificationCaller struct{}

func (SessionNotificationCaller) Notify(ctx context.Context, notification Notification) error {
	connection, err := dbus.ConnectSessionBus()
	if err != nil {
		return err
	}
	defer connection.Close()

	dbusObject := connection.Object("org.freedesktop.DBus", dbus.ObjectPath("/org/freedesktop/DBus"))
	var hasOwner bool
	if err := dbusObject.CallWithContext(
		ctx,
		"org.freedesktop.DBus.NameHasOwner",
		0,
		"org.freedesktop.Notifications",
	).Store(&hasOwner); err != nil {
		return err
	}
	if !hasOwner {
		return ErrNotificationServerUnavailable
	}

	object := connection.Object(
		"org.freedesktop.Notifications",
		dbus.ObjectPath("/org/freedesktop/Notifications"),
	)
	var notificationID uint32
	return object.CallWithContext(
		ctx,
		"org.freedesktop.Notifications.Notify",
		0,
		notification.AppName,
		uint32(0),
		notification.AppIcon,
		notification.Summary,
		notification.Body,
		notification.Actions,
		notification.Hints,
		notification.ExpireTimeout,
	).Store(&notificationID)
}
