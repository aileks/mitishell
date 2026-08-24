# Mitishell

Mitishell is a personal Hyprland shell built with QuickShell, QML, and a small Go companion binary. It targets Arch Linux and one coherent desktop experience. Do not turn it into a general shell framework.

## Read before changing behavior

- Read `ROADMAP.md` before adding a feature or expanding scope. Planned releases are vertical slices and the explicit non-goals are intentional. If a change completes or materially changes a roadmap item, update the roadmap with it.
- Read `README.md` before changing installation, configuration, external integrations, or weather behavior. Those are user-facing contracts.
- Prefer the smallest coherent change. Do not add machinery for hypothetical future use, and do not mix unrelated cleanup into feature or bug-fix work.

## Architecture

- `internal/` owns Go behavior: CLI, strict config validation/persistence, QuickShell IPC, and weather/network boundaries.
- `shell/core/` owns long-lived QML services and shared runtime state. Do not make individual components grow duplicate process, watcher, or service logic.
- `shell/lib/` is pure JavaScript. Put deterministic UI-facing transforms here when they can be tested without QML or I/O.
- `shell/components/` is presentation. Reuse neighboring patterns plus `Theme.qml`, `Motion.qml`, and shared components before inventing new ones. Motion must go through `Motion.duration(...)` so reduced motion still works.

Keep framework and I/O concerns at the edges. If logic is awkward to test, look for a cleaner boundary rather than mocking half of QuickShell.

## Visual design

Mitishell uses one fixed Cinder Grove visual language. Preserve the exact colors exposed by `Theme.qml` and the Adwaita Sans and Adwaita Mono families. Alpha variants of existing colors are allowed; do not add, remove, or change palette colors without an explicit request.

Favor layered organic depth, purposeful hierarchy, and sparse focal accents. Use shared primitives and theme tokens before styling individual surfaces. Establish or revise those foundations first during a whole-shell design pass. Motion should feel restrained and tactile, and must continue to use `Motion.duration(...)` so reduced motion remains equivalent and usable.

Each accent has one semantic owner:

- Orange: shell identity and primary runtime state
- Green: success and healthy or connected state
- Red: destructive, failed, and critical state
- Yellow: warning, stale, and pending state
- Blue: focus, configuration, and technical detail
- Purple: media
- Cyan: connectivity
- Pink: notifications and reminders

Use every accent meaningfully at least once, but do not spread accents decoratively. Universal state semantics override a surface's category accent: failures stay red, warnings stay yellow, and keyboard focus stays blue.

Visual and interaction changes may improve grouping, navigation, transitions, and feedback while preserving the planned feature set. Preserve keyboard access, visible focus, readability, reduced-motion parity, and multi-output behavior. Review representative flows across every surface family plus multi-output, reduced-motion, empty, unavailable, error, and content-overflow states.

## Sharp edges

**Config drift:** the config contract exists in both Go and QML. Schema/default changes usually require `internal/config` validation/default/get/set updates plus matching defaults/properties in `shell/core/Config.qml`. Test invalid input as well as the happy path.

**Multi-output behavior:** `shell/shell.qml` creates a `BarHost` per QuickShell screen. Bar, workspace, popover, and geometry work must not assume one monitor or one global surface.

**Session ownership:** Mitishell does not manage Hyprland config or autostart. Install/uninstall should touch Mitishell program files, not user config, cache, or session policy.

**Optional integrations:** missing external programs or services should make the related capability unavailable, not break the shell.

**Weather privacy:** weather is opt-in and uses `wttr.in`. Automatic location lets the provider infer a rough location from the network request; manual location sends the configured place text instead. Cache reuse must match both the requested location and unit system.

## Verification

While iterating, run the narrowest useful test: `go test ./internal/<package>` for Go or `node --test tests/<model>.test.js` for pure JS.

Before handing off a completed change, run `make check`. It runs the Go suite and race detector, Node model tests, formatting checks, `go vet`, `qmllint`, and whitespace validation.

For QML/visual work, run `make run` when QuickShell is available and exercise the actual affected surface. Lint is not visual verification. Behavior changes should get a focused regression test when there is a Go or pure-JS seam.
