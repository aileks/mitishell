# Mitishell

Mitishell (MY-ti-shell) is a personal Hyprland desktop shell built with QuickShell. It uses the Cinder Grove visual language and targets Arch Linux.

> [!WARNING]  
> This project is under active development.

## Requirements

- Hyprland
- QuickShell 0.3.0
- Go 1.26 or newer
- Qt 6 QML tooling
- Node.js
- GNU Make

Brightness control additionally needs `ddcutil` and read access to the monitors' i2c buses (typically membership in the `i2c` group). Wi-Fi needs NetworkManager and Bluetooth needs BlueZ running; when either is missing the related page reports unavailable and the rest of the shell is unaffected.

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
bin/mitishell notifications dnd
bin/mitishell power menu
bin/mitishell control
```

## Control center

`mitishell control` toggles the control center on the focused output. It has Home, Audio, Media, Display, Network, and Bluetooth pages; pass a page to land somewhere specific, for example `mitishell control audio`. The bar's control island opens it too. `mitishell network` and `mitishell bluetooth` are page shortcuts.

```ini
bindl = SUPER, D, exec, mitishell control
```

## Notifications, power, and connectivity

Mitishell runs its own notification server, so no external daemon is needed. The bar's bell island opens a popover with recent history, actions, and the do-not-disturb switch; toast cards stack under the same island, pause while that output is fullscreen or the session is locked, and land in history. `mitishell notifications dnd` toggles do-not-disturb; critical notifications still show.

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

## Source installation

> [!IMPORTANT]  
> `make uninstall` removes only installed program files. It doesn't remove user configuration or cache data.

```bash
make install
quickshell -n -p ~/.local/share/mitishell/shell

make uninstall
```

## License

Mitishell is licensed under the GPLv3 or later. See [LICENSE](LICENSE).
