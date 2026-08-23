# Roadmap

Mitishell grows through vertical features. Each completed feature updates this document in the same branch.

## Releases

Mitishell ships vertical slices as tagged releases.

- [x] v0.1.0: a working shell and bar replacing Waybar. Configuration, inter-process communication, CLI, and source installation. Bar islands for workspaces, active window, media, system metrics, audio, clock and calendar, weather, and tray. Notification and power compatibility actions
- [x] v0.2.0: On-Screen Display (OSD) for focused-output volume, microphone, and brightness. Display Data Channel (DDC) discovery with connector mapping, caching, and coalesced writes. Audio and brightness CLI actions
- [x] v0.3.0: focused-output control center with Home, Audio, Media, and Display pages. Reliable per-application stream controls. Shared state with bar popovers
- [x] v0.4.0: notifications, power, and connectivity. A notification server with popup cards, actions, history, session do-not-disturb, and lock and fullscreen policies, replacing swaync. WPA2 and WPA3 Personal Wi-Fi with hidden and saved networks, connection failures, and Ethernet status. Bluetooth discovery, pairing with passkey entry and confirmation, trust, connection management, battery state, and a Go BlueZ Agent1 adapter. Lock, logout, suspend, conditional hibernate, reboot, and shutdown with morphing confirmation, replacing wlogout.
- [x] v0.5.0: settings and hardening. A centered settings window with immediate validated configuration updates and inline errors. Consistent keyboard handling and reduced motion. Recovery from display churn. Service error states. Diagnostics for the notification server and bus services. Hardened install and uninstall. Weather refresh after resume or network recovery.
- [x] v0.5.1: notification popups follow their screen correctly on multi-output setups
- [ ] v0.6.0: notification and OSD depth. Popup cards and history show images and avatars. Display durations follow urgency. History persists to disk across reloads and restarts. A generic CLI-driven OSD accepts any icon, message, and progress. Timed reminders with a review overlay
- [ ] v0.7.0: bar, clock, and weather depth. Keyboard-layout and available-update bar widgets. The update widget counts `pacman` and AUR updates without installing anything. Week numbers in the calendar grid, alternate clock formats, and timezone selection. Bar islands reorder by dragging and persist through configuration. Weather location drops GeoClue. The provider detects location from the network by default. A manual location, searchable by place name, overrides detection. Set it from the CLI, the weather popover, or the settings window
- [ ] v0.8.0: new surfaces. A searchable emoji picker overlay and a nightlight indicator that toggles an external tool at runtime (no bundled daemon)
- [ ] v0.9.0: visual polish. Contrast meets the Web Content Accessibility Guidelines (WCAG) at level AA: 4.5:1 for body text and 3:1 for large text and UI edges. An accent audit either uses each Theme.qml accent consistently with its category or removes it. Spacing and type scale reconcile with Theme.qml constants. Verify each round with screenshots of every surface via make run. Rounds repeat until it feels right
- [ ] v1.0: one week of normal use as the primary shell followed by user acceptance and an annotated release tag

## Known issues

- [x] corrected the default proportional fonts and type scale across the bar and popovers
- [x] stabilized workspace labels while the active pill animates
- [x] grouped duplicate Media Player Remote Interfacing Specification (MPRIS) instances and followed replacement player state
- [x] tightened media island padding and scrolled long metadata on one line
- [x] aligned audio popover spacing and typography with the system surface
- [x] replaced the generic tray list with directly interactive tray icons

## Planned after v1

- Validated laptop battery, charging, backlight, lid, dock, suspend, and resume support
- hotspot hosting
- Editing saved networks from the network page
- AUR packaging
- Keyboard-backlight OSD
- Caps-lock and num-lock OSD
- Inline notification replies
- Bar position and transparency options

## Explicit non-goals

- Other compositor backends
- Public plugin or theme marketplaces
- Dynamic third-party plugin loading
- Application launcher or clipboard manager
- Custom lock, authentication, polkit, display-manager, or package-manager stacks
- External calendar synchronization
- Enterprise Wi-Fi, Virtual Private Network (VPN) ownership or authentication, and Ethernet profile editing
- Wallpaper, theme, and font management
- Idle timers and session policy ownership
- Mutating configuration or state outside Mitishell's own
