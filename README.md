# Mitishell

> [!WARNING]  
> This project is under active development.

Mitishell (MY-ti-shell) is a personal Hyprland desktop shell built with QuickShell. It uses the Cinder Grove visual language and targets Arch Linux.

## Requirements

- Hyprland
- QuickShell 0.3.0
- Go 1.26 or newer
- Qt 6 QML tooling
- Node.js
- GNU Make
- A Nerd Font for shell and OSD glyphs

Brightness control additionally needs `ddcutil` and read access to the monitors' i2c buses (typically membership in the `i2c` group). Wi-Fi needs NetworkManager and Bluetooth needs BlueZ running; when either is missing the related page reports unavailable and the rest of the shell is unaffected.

Reminders additionally need a working user systemd session with `systemd-run` and `systemctl`. Missing reminder dependencies disable reminders without affecting the rest of the shell.

The update widget needs `checkupdates` from `pacman-contrib`. AUR counts and upgrades additionally use `paru` or `yay`, preferring `paru`. Missing optional update tools hide or reduce the widget without affecting the shell. Launching an update also needs `xdg-terminal-exec`, `$TERMINAL`, foot, Alacritty, kitty, or Ghostty. Mitishell only shows the command and launches it after explicit activation.

## Development

```bash
make build
make test   # runs the Go suite and the pure JavaScript models shared with QML
make check  # adds Go formatting and vet checks plus QML linting.
make run
```

## Configuration

Mitishell reads `$XDG_CONFIG_HOME/mitishell/config.json`. When the file is absent, Mitishell falls back to built-in defaults without creating it.

Set `MITISHELL_QS_PATH` to the repository's `shell` directory when you use CLI commands that talk to a development instance.

```bash
bin/mitishell config path
bin/mitishell config validate
bin/mitishell config get bar.outputs
bin/mitishell config set weather.enabled true
bin/mitishell weather location "New York"
bin/mitishell weather location auto
bin/mitishell notifications dnd
bin/mitishell power menu
bin/mitishell settings
bin/mitishell control
```

`bar.islands` is the persisted right-island order. It accepts a JSON string array through `config set`; unknown and duplicate ids are removed and missing ids return in the default order. The clock defaults to 24-hour time. Right-click its bar label to cycle persisted 24-hour, 12-hour, and seconds variants. `clock.showDate`, `clock.timezones`, and `calendar.showWeekNumbers` control the remaining clock and calendar details.

## Weather

Weather is opt-in. When enabled, Mitishell sends either the configured place name or an automatic-location request to [wttr.in](https://wttr.in/) and caches the last successful three-day forecast. Automatic mode allows wttr.in to infer a rough location from the request's network address. A manual place avoids that inference request but still sends the place text to wttr.in.

Set a place with `mitishell weather location <place...>`, clear it with `mitishell weather location auto`, or use the shared editor in the weather popover and settings window. `weather.location` stores the manual query, while an empty value means automatic detection. `weather.units` accepts `auto`, `celsius`, or `fahrenheit`. Cached data is reused only for the same query and unit system.

## Control center

`mitishell control` toggles the control center on the focused output. It has Home, Audio, Media, Display, Network, and Bluetooth pages; pass a page to land somewhere specific, for example `mitishell control audio`. The bar's control island opens it too. `mitishell network` and `mitishell bluetooth` are page shortcuts.

```ini
bindl = SUPER, D, exec, mitishell control
```

## Settings

`mitishell settings` opens a centered settings window, also reachable from the control center's Home page. It exposes bar layout, islands, weather, and motion fields. Every change saves immediately through the same validation as `mitishell config set`, applies live, and reports validation errors inline.

```ini
bindl = SUPER, C, exec, mitishell settings
```

## Notifications, power, and connectivity

Mitishell runs its own notification server, so no external daemon is needed. The bar's bell island opens a popover with recent history, actions, and the do-not-disturb switch; toast cards stack under the same island, pause while that output is fullscreen or the session is locked, and land in history. `mitishell notifications dnd` toggles do-not-disturb; critical notifications still show.

The newest 50 non-transient notifications persist across reloads and restarts. State lives at `$XDG_STATE_HOME/mitishell/notifications/history.json`, or `~/.local/state/mitishell/notifications/history.json` when `XDG_STATE_HOME` is unset. Captured avatars and content images live in the sibling `media` directory. Restored notifications are history-only and don't retain live actions.

The power menu is a centered overlay with lock, logout, suspend, hibernate, reboot, and shutdown. Choosing an action morphs it into a confirmation. Suspend and hibernate appear only when logind supports them, and locking goes through the session's lock signal so your idle daemon decides what locks the screen.

The Network page lists Wi-Fi stations with signal and security, joins secured and hidden networks inline, and shows Ethernet state; it drives NetworkManager. The Bluetooth page pairs and manages devices through BlueZ, including passkey confirmation and battery readouts for devices that report them. Enterprise Wi-Fi sign-in stays out of scope.

## Volume, microphone, and brightness

`volume`, `mic`, and `brightness` apply their change in the running shell and show an OSD on the focused output. Bind them in Hyprland with:

```ini
bindel = , XF86AudioRaiseVolume, exec, mitishell volume up
bindel = , XF86AudioLowerVolume, exec, mitishell volume down
bindl  = , XF86AudioMute,        exec, mitishell volume mute
bindl  = , XF86AudioMicMute,     exec, mitishell mic mute
bindel = , XF86MonBrightnessUp,   exec, mitishell brightness up
bindel = , XF86MonBrightnessDown, exec, mitishell brightness down
```

Both also accept absolute values (`mitishell volume set 40`, `mitishell brightness set 60`). Volume steps stay within 100 percent and unmute; the audio island wheel and popover slider still reach 150 percent. Brightness drives every DDC/CI monitor, floors at 1 percent so a step can always be undone on screen, and coalesces rapid changes into few ddcutil writes.

## Generic OSD

Show a focused-output OSD from scripts with any combination of icon, message, and progress:

```bash
mitishell osd --icon info --message "Build finished"
mitishell osd --message "Syncing" --progress 65 --duration 2000
mitishell osd --icon '󰔛' --message "Nerd Font glyph"
```

At least one of `--icon`, `--message`, or `--progress` is required. Progress accepts 0 through 100, duration accepts 250 through 30000 milliseconds, and the default duration is 1200 milliseconds. Icons resolve through Mitishell aliases, readable local files, bundled icons, freedesktop theme icons, then Nerd Font glyphs or text. Remote image URLs are rejected.

## Reminders

`mitishell reminder` opens the centered review-and-create overlay on the focused output. The CLI can also schedule, list, and clear timers:

```bash
mitishell reminder 10
mitishell reminder 25 Check the oven
mitishell reminder list
mitishell reminder clear
```

Messages are optional. An omitted message becomes `Your N minutes are up`. Active reminders appear beside the notification control and remain individually cancellable in the overlay. Scheduling and cancellation use a pink OSD instead of adding history entries.

Timers are transient user-systemd units. Their private metadata lives under `$XDG_RUNTIME_DIR/mitishell/reminders`, so active and pending reminders end with the login session and don't survive logout or reboot. Fired reminders become normal-urgency Mitishell notifications, bypass do-not-disturb, and remain in notification history. If the notification server is absent when a timer fires, Mitishell retains that delivery until it returns during the same login.

## Source installation

> [!IMPORTANT]  
> `make uninstall` removes only installed program files. It retains user configuration, cache data, and notification history under the state directory.

```bash
make install
quickshell -n -p ~/.local/share/mitishell/shell

make uninstall
```

## License

Mitishell is licensed under the GPLv3 or later. See [LICENSE](LICENSE).
