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

See [ROADMAP.md](ROADMAP.md) for release scope and deferred features.

## License

Mitishell is licensed under GPL-3.0-or-later. See [LICENSE](LICENSE).
