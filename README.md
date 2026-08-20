# Mitishell

Mitishell is a personal Hyprland desktop shell built with QuickShell. It uses the Cinder Grove visual language and targets Arch Linux.

> [!WARNING]  
> This project is under active development.

## Requirements

- Hyprland
- QuickShell 0.3.0
- Go 1.26 or newer
- Qt 6 QML tooling
- Node.js
- GNU Make

## Development

```bash
make build
make test
make check
make run
```

`make test` runs the Go suite and the pure JavaScript models shared with QML.
`make check` adds Go formatting and vet checks plus QML linting.

`make run` starts the shell from the repository. It does not modify Hyprland configuration or session startup.

The current shell foundation renders output-specific Hyprland workspaces and
window titles plus an MPRIS media island with artwork, playback controls,
progress, and session-only player selection. The right island supports separate,
combined, or hidden CPU and memory metrics. Its popover includes load average,
uptime, optional thermal data, and a Mission Center action. Native PipeWire
controls provide output and input volume, mute, and default-device selection.

## Configuration

Mitishell reads `$XDG_CONFIG_HOME/mitishell/config.json`. When the file is absent, built-in defaults are used without creating it.

```bash
bin/mitishell config path
bin/mitishell config validate
bin/mitishell config get bar.outputs
bin/mitishell config set weather.enabled true
```

Set `MITISHELL_QS_PATH` to the repository's `shell` directory when using CLI IPC commands against a development instance.

## Source installation

```bash
make install
quickshell -n -p ~/.local/share/mitishell/shell
```

The session manager remains user-owned. Mitishell does not add or change an autostart entry.

`make uninstall` removes only installed program files. It does not remove user configuration or cache data.

See [ROADMAP.md](ROADMAP.md) for release scope and deferred features.

## License

Mitishell is licensed under GPL-3.0-or-later. See [LICENSE](LICENSE).
