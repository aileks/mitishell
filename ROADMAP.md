# Roadmap

Mitishell is developed as vertical features. Each completed feature updates this document in the same branch.

## v0.1 Waybar replacement

- [x] Shell foundation, configuration, IPC, CLI, and source installation
- [x] Workspaces and active window
- [x] Media island and popover
- [x] System metrics and popover
- [x] Audio controls and popover
- [x] Clock and calendar
- [x] Local weather and forecast popover
- [x] System tray and menus
- [x] Notification and power compatibility actions

## Planned releases

- [ ] v0.2: focused-output volume, microphone, and brightness OSDs; DDC discovery, connector mapping, caching, and coalesced writes; audio and brightness CLI actions
- [ ] v0.3: focused-output control center with Home, Audio, Media, and Display pages; reliable per-application stream controls; shared state with bar popovers
- [ ] v0.4: notification daemon, popup cards, actions, live notification center, session DND, and lock and fullscreen policies; replace SwayNC
- [ ] v0.5: WPA2 and WPA3 Personal Wi-Fi, hidden and saved networks, phone-hotspot joining, connection details and failures, and Ethernet status
- [ ] v0.6: Bluetooth discovery, pairing, passkey entry and confirmation, trust, connection management, battery state, and a Go BlueZ Agent1 adapter
- [ ] v0.7: lock, logout, suspend, conditional hibernate, reboot, and shutdown with morphing confirmation; replace wlogout
- [ ] v0.8: centered settings window, immediate atomic configuration updates, validation errors, weather opt-in, and a restrained set of supported fields
- [ ] v0.9: keyboard and reduced-motion consistency, monitor and device churn, failure states, diagnostics, install and uninstall hardening, and weather refresh after resume or meaningful network recovery
- [ ] v1.0: one week of normal-use dogfooding followed by user acceptance and an annotated release tag

## Known issues

- [ ] v0.9: correct the default proportional fonts and type scale across the bar and popovers
- [ ] v0.9: prevent workspace pill text from shifting during odd-to-even workspace transitions
- [ ] v0.9: remove the duplicated sound-source indicator from the center media island
- [ ] v0.9: correct spacing and text sizing in the audio popover

## Planned after v1

- Validated laptop battery, charging, backlight, lid, dock, suspend, and resume support
- Hotspot hosting
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
