# Roadmap

Mitishell grows one slice at a time. When a slice ships, update this file on the same branch.

## Releases

Each tag ships one useful slice.

- [x] v0.1.0: a shell and bar took the place of Waybar. This tag added config, IPC, the CLI, and source install. Bar islands showed workspaces, the active window, media, system stats, sound, time, date, weather, and the tray. It also added hooks for notifications and power tools
- [x] v0.2.0: an on-screen display (OSD) showed sound, mic, and light level on the focused output. Display Data Channel (DDC) scan found each link and cached the map. It grouped fast writes. The CLI gained sound and light controls
- [x] v0.3.0: the focused output gained a control center. It had Home, Audio, Media, and Display pages. App stream controls worked well. Bar popovers shared the same state
- [x] v0.4.0: notifications, power, and network links. A new notification server took the place of swaync. It had popup cards, actions, history, do-not-disturb, and rules for lock and full screen. Wi-Fi could join WPA2 and WPA3 Personal links, hidden links, and saved links. It showed link errors and Ethernet state. Bluetooth could scan, pair, ask for a passkey, trust, link, and show battery state. A Go BlueZ Agent1 tool handled pair requests. A new menu took the place of wlogout. It could lock, log out, sleep, hibernate when safe, reboot, and shut down after a prompt
- [x] v0.5.0: settings and hardening. A window let users change valid config and see errors at once. Keys worked the same in all views. Reduced motion had full support. The shell could heal after screen churn. Services showed clear error states. New checks covered the notification server and bus services. Install and uninstall became safer. Weather could refresh after wake or network loss
- [x] v0.5.1: notification popups moved to the right screen in a multi-output setup
- [x] v0.6.0: more depth for notifications and the OSD, plus a base-first design pass. Shared parts gave each view depth, clear rank, Adwaita type, sparse accents, and calm motion. Popup cards and history split avatars from content art. They used time based on need and stayed through restarts. The OSD took aliases, images, theme icons, Nerd Font glyphs, text, and progress. Timed notes used short-lived user systemd timers and a key-first review panel. They added bar state, pink OSD hints, and normal notifications that bypass do-not-disturb. The review checked key flows in the bar, popovers, control center, settings, notifications, OSD, notes, and power menu. It also checked many outputs, reduced motion, keys, overflow, blank states, lost tools, and errors
- [x] v0.7.0: more depth for the bar, clock, and weather. New bar tools showed the key map and updates. The update tool counted `pacman` and AUR updates but didn't install them. The date grid showed week numbers. Users could pick a time zone and select the clock to cycle its form. Dragging moved bar islands, and config saved the order. The tray grew in place. The media island fit its content. wttr.in gave a three-day view. It used network-based auto location or a place set in the CLI, weather popover, or settings window
- [x] v0.8.0: new views. A focused-output picker searches a bundled emoji catalog, groups categories, copies selections, and keeps recents. The Control Center and CLI show and switch a user-managed hyprsunset with focused-output OSD feedback. Mitishell does not own a night-light daemon or configuration
- [x] v0.9.0: the final pre-1.0 audit strengthened WCAG AA text and interactive-edge contrast, normalized shared surfaces and accent roles, added pointer and focus feedback, and moved settings into the Control Center while retaining Home's compact now-playing card. Stabilization fixed audio list scrolling, Bluetooth discovery and device actions, Wi-Fi power control, weather locale and refresh races, multi-output focus placement, and QML lint noise. The review covered the bar, islands, popovers, notification surfaces, every Control Center page, settings, emoji, reminders, power, and OSD states across both available outputs with keyboard and reduced-motion checks
- [ ] v1.0: use Mitishell as the main shell for one week. Then run user sign-off and add a release tag with notes

## Known issues

- [x] fixed the base font and type scale in the bar and popovers
- [x] kept workspace labels still while the active pill moves
- [x] grouped duplicate Media Player Remote Interfacing Specification (MPRIS) apps and tracked a new player when it took over
- [x] cut media island space and moved long track text on one line
- [x] matched sound popover space and type with the system view
- [x] replaced the plain tray list with tray icons users can press

## Planned after v1

- Check laptop battery, charge, screen light, lid, dock, sleep, and wake support
- Host a hotspot
- Edit saved links on the network page
- Make an AUR package
- Show key backlight in the OSD
- Show Caps Lock and Num Lock in the OSD
- Reply to notifications in place
- Set bar side and alpha

## Explicit non-goals

- Other screen tool backends
- Public stores for plugins or themes
- Load third-party plugins at run time
- App launch or clipboard tools
- Custom lock, auth, polkit, display manager, or package manager stacks
- Sync with an outside calendar
- Own or sign in to Enterprise Wi-Fi or a Virtual Private Network (VPN), or edit Ethernet profiles
- Manage the wallpaper, theme, or fonts
- Own idle timers or session rules
- Change config or state owned by other apps
