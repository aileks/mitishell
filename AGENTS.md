# Mitishell

Mitishell gives Hyprland a shell built with QuickShell, QML, and a small Go tool. It runs on Arch Linux and aims for one clear desktop flow. Keep that focus. Don't turn it into a shell framework for all needs.

## Read before changing behavior

- Read `ROADMAP.md` before adding a feature or more scope. Each planned tag ships one useful slice. The non-goals set firm limits. Update the roadmap when a change ends or alters an item.
- Read `README.md` before changing install steps, settings, outside links, or weather. Those facts form user-facing contracts.
- Prefer the smallest sound change. Avoid tools for future use. Keep stray cleanup out of feature and bug-fix work.

## Architecture

- `internal/` owns Go work. This covers the CLI, strict config checks and files, QuickShell IPC, and weather or network edges.
- `shell/core/` owns long-lived QML services and shared state. Keep repeat process, watch, and service code out of single parts.
- `shell/lib/` holds pure JavaScript. Put stable UI maps here when tests can run without QML or I/O.
- `shell/components/` draws the UI. Reuse nearby forms, `Theme.qml`, `Motion.qml`, and shared parts before adding more. Route all motion through `Motion.duration(...)`. This keeps reduced motion in sync.

Keep framework and I/O work at the edges. If tests feel hard, seek a clean seam instead of mocking half of QuickShell.

## Visual design

Mitishell uses one fixed Cinder Grove look. Keep the exact colors from `Theme.qml`. Keep the Adwaita Sans and Adwaita Mono fonts. You may use alpha forms of these colors. Change the set only when the user asks.

Favor soft depth, clear rank, and sparse focal accents. Use shared parts and theme tokens before you style one view. In a full shell design pass, fix those bases first. Motion should feel calm and firm. Keep using `Motion.duration(...)` so reduced motion has the same flow.

Each accent has one semantic owner:

- Orange: shell brand and main run state
- Green: success and good or linked state
- Red: harm, error, and dire state
- Yellow: warning, stale, and pending state
- Blue: focus, config, and tech detail
- Purple: media
- Cyan: connectivity
- Pink: notes and reminders

Give each accent at least one clear use. Avoid accents used just for looks. Shared state rules override a view accent. Errors stay red, warnings stay yellow, and key focus stays blue.

Visual and input work may improve groups, paths, motion, and feedback while keeping the planned set. Preserve key access, seen focus, clear text, reduced-motion parity, and many-screen use. Review key flows for each view group. Check many screens, reduced motion, blank, lost, error, and overflow states.

## Sharp edges

**Config drift:** Go and QML share the config rules. Schema or base value changes need matched work in `internal/config` and `shell/core/Config.qml`. Test bad input and the happy path.

**Multi-output behavior:** `shell/shell.qml` makes one `BarHost` per QuickShell screen. Bar, workspace, popover, and layout work must support many screens and views.

**Session ownership:** Mitishell doesn't own Hyprland config or autostart. Install and uninstall steps should touch app files only. Leave user config, cache, and session rules alone.

**Extra tools:** when an outside app or service goes missing, hide its feature without harm to the shell.

**Weather privacy:** users must turn on weather, which uses `wttr.in`. Auto mode lets the host infer a rough place from the request. Manual mode sends the saved place text. Reuse cache data only when the place and unit type match.

## Git flow

1. Create a feature branch unless the user says to stay put. Keep quick fixes and docs passes on the current branch.
2. Make small, focused commits as work moves on.
3. Run `make test` after the work ends.
4. Merge the branch into `dev`. Then do a quick code review without the code review skill.
5. Check code, UX, UI, and all other key risks. Once they pass, merge `dev` into `main`.
6. Add a tag when the release needs one. Use past releases as the form for its notes.

## Verification

As you work, run the smallest useful test. Use `go test ./internal/<package>` for Go. Use `node --test tests/<model>.test.js` for pure JS.

Before handoff, run `make check`. It runs the Go suite and race check. It also runs Node model tests, format checks, `go vet`, `qmllint`, and space checks.

For QML or visual work, run `make run` when QuickShell works. Try the changed view. Lint can't check what you see. Add a focused test for a change in use when Go or pure JS gives a clean seam.
