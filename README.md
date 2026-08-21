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
bin/mitishell notifications toggle
bin/mitishell power menu
```

## Source installation

> [!NOTE]  
> `make uninstall` removes only installed program files. It doesn't remove user configuration or cache data.

```bash
make install
quickshell -n -p ~/.local/share/mitishell/shell

make uninstall
```

## License

Mitishell is licensed under the GPLv3 or later. See [LICENSE](LICENSE).
