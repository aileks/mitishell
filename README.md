# Mitishell

Mitishell (MY-ti-shell) is a personal Hyprland desktop shell built with QuickShell. It uses the Cinder Grove visual language and targets Arch Linux.

## Requirements

- Hyprland
- hyprshutdown
- QuickShell 0.3.0
- Go 1.26 or newer
- Qt 6 QML tooling
- Node.js
- GNU Make
- A Nerd Font for shell and OSD glyphs

Brightness control additionally needs `ddcutil` and read access to the monitors' i2c buses (typically membership in the `i2c` group). Wi-Fi needs NetworkManager and Bluetooth needs BlueZ running; when either is missing the related page reports unavailable and the rest of the shell is unaffected.

Reminders additionally need a working user systemd session with `systemd-run` and `systemctl`. Missing reminder dependencies disable reminders without affecting the rest of the shell.

The update widget needs `checkupdates` from `pacman-contrib`. AUR counts and upgrades additionally use `paru` or `yay`. Missing optional update tools hide or reduce the widget without affecting the shell. Launching an update also needs `xdg-terminal-exec`, `$TERMINAL`, foot, Alacritty, kitty, or Ghostty. Mitishell only shows the command and launches it after explicit activation. Checks run when the shell starts and daily at 09:00 local time; a failed check retries every few minutes until it succeeds.

Night-light controls need a user-managed `hyprsunset` process. Mitishell reads and switches its live state through `hyprctl`, setting 4800 K when it turns night light on. It does not start, supervise, or persist configuration for the outside tool. The control stays hidden when `hyprsunset` is not running.

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
bin/mitishell settings audio
bin/mitishell emoji
bin/mitishell night-light status
```

`bar.layout` persists the built-in widgets assigned to the bar's `left`, `center`, `right`, and `hidden` sections. A widget can appear once, and the center accepts at most three. Drag widgets directly on the bar or in Settings > System. Responsive overflow never changes the saved layout. Version 1 configs are migrated in memory and remain untouched until the next persistent config change writes version 2.

The default layout keeps Audio and Bluetooth separate and groups Wi-Fi, brightness, do-not-disturb, night light, and reminder access behind one Quick Settings cog. A separate Network widget remains available in bar configuration and defaults to Hidden. Brightness lives in Quick Settings and Settings > Display. The compact reminder indicator appears only while a reminder is active.

The clock defaults to 24-hour time. Right-click its bar label to cycle persisted 24-hour, 12-hour, and seconds variants. `clock.showDate`, `clock.timezones`, and `calendar.showWeekNumbers` control the remaining clock and calendar details.

`font.family` picks the standard font family used for labels and titles; an empty value follows the system UI font. `font.monoFamily` picks the monospace family used for data text and icons; an empty value keeps the shipped AdwaitaMono Nerd Font Propo. Monospace accepts only Nerd Font families: the shell's icons are Nerd Font glyphs, so an unpatched family would leave the bar without icons. Settings > System offers both pickers under Font, and invalid values are rejected with the same validation as any other key.

## Weather

Weather is opt-in. When enabled, Mitishell sends either the configured place name or an automatic-location request to [wttr.in](https://wttr.in/) and caches the last successful three-day forecast. Automatic mode allows wttr.in to infer a rough location from the request's network address. A manual place avoids that inference request but still sends the place text to wttr.in.

Set a place with `mitishell weather location <place...>`, clear it with `mitishell weather location auto`, or use the shared editor in the weather popover and Settings > System. `weather.location` stores the manual query, while an empty value means automatic detection. `weather.units` accepts `auto`, `celsius`, or `fahrenheit`. Auto follows the locale's measurement region. Cached data is reused only for the same query and unit system.

## Settings

`mitishell settings` toggles Settings on the focused output. Its pages are Overview, Audio, Display, Network, Bluetooth, and System. Pass a page to land somewhere specific, for example `mitishell settings audio`. Overview keeps compact quick controls and a now-playing card. System contains persistent Mitishell preferences, including the full bar layout. Every preference saves through the same validation as `mitishell config set`, applies live, and reports validation errors inline.

The bar's Quick Settings cog exposes shared quick controls and routes deeper work to Settings on the same output. Its Open Settings button opens Overview. Audio and Bluetooth have their own bar widgets and complete Settings pages. An optional Network bar widget provides its own short quick-control popover. `mitishell network` and `mitishell bluetooth` remain page shortcuts. `mitishell control` is retained as a compatibility alias, with `home` mapped to Overview and its old `settings` page mapped to System.

```ini
bindl = SUPER, D, exec, mitishell settings
```

## Notifications, power, and connectivity

Mitishell runs its own notification server, so no external daemon is needed. The bar's notification widget opens a popover with recent history, actions, and the do-not-disturb switch; toast cards stack under the same widget, pause while that output is fullscreen or the session is locked, and land in history. `mitishell notifications dnd` toggles do-not-disturb; critical notifications still show.

The newest 50 non-transient notifications persist across reloads and restarts. State lives at `$XDG_STATE_HOME/mitishell/notifications/history.json`, or `~/.local/state/mitishell/notifications/history.json` when `XDG_STATE_HOME` is unset. Captured notification images and application icons live in the sibling `media` directory. Restored notifications are history-only and don't retain live actions.

The power menu is a centered overlay with lock, logout, suspend, hibernate, reboot, and shutdown. Choosing an action morphs it into a confirmation. Suspend and hibernate appear only when logind supports them, and locking goes through the session's lock signal so your idle daemon decides what locks the screen.

The Network page toggles Wi-Fi, lists stations with signal and security, joins secured and hidden networks inline, and shows Ethernet state; it drives NetworkManager. The Bluetooth page scans while open and pairs and manages devices through BlueZ, including passkey confirmation and battery readouts for devices that report them. Enterprise Wi-Fi sign-in stays out of scope.

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

Both also accept absolute values (`mitishell volume set 40`, `mitishell brightness set 60`). Volume steps stay within 100 percent and unmute; the audio widget wheel and popover slider still reach 150 percent. Brightness drives every DDC/CI monitor, floors at 1 percent so a step can always be undone on screen, and coalesces rapid changes into few ddcutil writes.

## Generic OSD

Show a focused-output OSD from scripts with any combination of icon, message, and progress:

```bash
mitishell osd --icon info --message "Build finished"
mitishell osd --message "Syncing" --progress 65 --duration 2000
mitishell osd --icon '󰔛' --message "Nerd Font glyph"
```

At least one of `--icon`, `--message`, or `--progress` is required. Progress accepts 0 through 100, duration accepts 250 through 30000 milliseconds, and the default duration is 1200 milliseconds. Icons resolve through Mitishell's Nerd Font aliases, readable local files, freedesktop theme icons, then literal glyphs or text. Remote image URLs are rejected.

## Emoji picker

`mitishell emoji` toggles a centered picker on the focused output. Type to search the complete bundled catalog, use the category row or arrow and page keys to move, and press Enter or select a cell to copy it. Escape clears an active search before closing the picker.

The picker keeps the 24 most recently copied unique emojis and exposes a clear action in its Recents category. This state lives at `$XDG_STATE_HOME/mitishell/emoji-recents.json`, or `~/.local/state/mitishell/emoji-recents.json` when `XDG_STATE_HOME` is unset.

```ini
bind = SUPER, PERIOD, exec, mitishell emoji
```

## Night light

Mitishell controls the identity state and reports the current color temperature of an already-running `hyprsunset`. Enabling night light sets the live temperature to 4800 K. Settings > Overview shows the live state and polls frequently while Settings is open. Successful changes show a focused-output OSD.

```bash
mitishell night-light on
mitishell night-light off
mitishell night-light toggle
mitishell night-light status
```

`status` prints `on <kelvin> K` or `off <kelvin> K`. Commands fail without starting anything when `hyprsunset` is absent or stopped.

## Reminders

`mitishell reminder` opens the centered review-and-create overlay on the focused output. The CLI can also schedule, list, and clear timers:

```bash
mitishell reminder 10
mitishell reminder 25 Check the oven
mitishell reminder list
mitishell reminder clear
```

Messages are optional. An omitted message becomes `Your N minutes are up`. Reminder access remains in the bar's status group, with active reminders available in a bounded quick popover and individually cancellable in the overlay. Scheduling and cancellation use a pink OSD instead of adding history entries.

Timers are transient user-systemd units. Their private metadata lives under `$XDG_RUNTIME_DIR/mitishell/reminders`, so active and pending reminders end with the login session and don't survive logout or reboot. Fired reminders become normal-urgency Mitishell notifications, bypass do-not-disturb, and remain in notification history. If the notification server is absent when a timer fires, Mitishell retains that delivery until it returns during the same login.

## Prebuilt installation

Each release includes Linux archives for amd64 and arm64. The archive contains the Mitishell binary, QML shell, desktop entry, required third-party notices, and license files.

```bash
tar -xzf mitishell-v1.0.1-linux-amd64.tar.gz
cd mitishell-v1.0.1-linux-amd64
make install-prebuilt
quickshell -n -p ~/.local/share/mitishell/shell
```

Use the arm64 archive on an arm64 system. Verify downloads with the release's `SHA256SUMS` file before installing.

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

The prebuilt binary includes third-party software. See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
