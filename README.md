# Mitishell

Mitishell is a personal Hyprland desktop shell built with QuickShell. It uses the Cinder Grove visual language and targets Arch Linux.

The project is under active development. The first release replaces Waybar while SwayNC, SwayOSD, and wlogout remain available.

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
make check
make run
```

`make run` starts the shell from the repository. It does not modify Hyprland configuration or session startup.

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
