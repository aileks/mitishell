# Roadmap

Mitishell grows through vertical features. Each completed feature updates this document in the same branch.

## v0.1.0 Waybar replacement

- [x] Shell foundation, configuration, IPC, CLI, and source installation
- [x] Workspaces and active window
- [x] Media island and popover
- [x] System metrics and popover
- [x] Audio controls and popover
- [x] Clock and calendar
- [x] Local weather and forecast popover
- [x] System tray and menus
- [x] Notification and power compatibility actions

## Releases

The plan below originally split this work across v0.2 through v0.9. Scope merged along the way, and the work shipped as five tagged releases.

- [x] v0.2.0: focused-output volume, microphone, and brightness OSDs; DDC discovery, connector mapping, caching, and coalesced writes; audio and brightness CLI actions
- [x] v0.3.0: focused-output control center with Home, Audio, Media, and Display pages; reliable per-application stream controls; shared state with bar popovers
- [x] v0.4.0: notifications, power, and connectivity. A notification server with popup cards, actions, history, session do-not-disturb, and lock and fullscreen policies, replacing swaync. WPA2 and WPA3 Personal Wi-Fi with hidden and saved networks, connection failures, and Ethernet status. Bluetooth discovery, pairing with passkey entry and confirmation, trust, connection management, battery state, and a Go BlueZ Agent1 adapter. Lock, logout, suspend, conditional hibernate, reboot, and shutdown with morphing confirmation, replacing wlogout.
- [x] v0.5.0: settings and hardening. A centered settings window with immediate validated configuration updates and inline errors. Keyboard and reduced-motion consistency, monitor churn recovery, service failure states, diagnostics for the notification server and bus services, install and uninstall hardening, and weather refresh after resume or network recovery.
- [ ] v1.0: one week of normal-use dogfooding followed by user acceptance and an annotated release tag

## Known issues

- [x] corrected the default proportional fonts and type scale across the bar and popovers
- [x] stabilized workspace labels while the active pill animates
- [x] grouped duplicate MPRIS instances and followed replacement player state
- [x] tightened media island padding and scrolled long metadata on one line
- [x] aligned audio popover spacing and typography with the system surface
- [x] replaced the generic tray list with directly interactive tray icons

## Planned after v1

- Validated laptop battery, charging, backlight, lid, dock, suspend, and resume support
- hotspot hosting
- AUR packaging
- Keyboard-backlight OSD
- Caps-lock and num-lock OSD
- Inline notification replies

## Explicit non-goals

- Other compositor backends
- Public plugin or theme marketplaces
- Dynamic third-party plugin loading
- Application launcher or clipboard manager
- Custom lock, authentication, polkit, display-manager, or package-manager stacks
- External calendar synchronization
- Enterprise Wi-Fi, VPN ownership or authentication, and Ethernet profile editing
