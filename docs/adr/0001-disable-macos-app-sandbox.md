# ADR-0001: Disable the macOS App Sandbox

- Status: Accepted
- Date: 2026-07-16

## Context

ZeroBox ships a GUI, CLI, and persistent daemon from the same Flutter macOS application executable. The GUI starts the daemon by executing itself with `--nogui daemon run`, then communicates with it through a per-user Unix socket.

When the GUI is App Sandbox-enabled, a child process inherits the GUI sandbox. Executing the sandbox-entitled application binary inside that inherited sandbox makes macOS initialise App Sandbox a second time. The kernel rejects the daemon before Dart starts with `deny(1) forbidden-sandbox-reinit`, so no daemon socket is created.

ZeroBox also needs Bluetooth, local package access, community plugins, CLI operation, and persistent background device or installation tasks. The project is distributed directly and does not target the Mac App Store.

## Decision

ZeroBox does not enable App Sandbox for macOS Debug, Profile, or Release builds.

Debug and Profile builds retain `com.apple.security.cs.allow-jit` for the Flutter runtime. All builds retain `com.apple.security.files.user-selected.read-write` because ZeroBox imports local packages and exports files, including the plugin `file.unload` API, through the macOS file picker. None of these builds enable `com.apple.security.app-sandbox`. The project may distribute source code, unsigned or ad-hoc-signed development builds, or independently packaged builds. Developer ID signing and Apple notarisation are optional release conveniences for reducing Gatekeeper friction, not requirements of this decision.

The GUI continues to launch the same application executable in `--nogui daemon run` mode. GUI and daemon remain separate processes connected through the existing authenticated local protocol and Unix socket.

## Consequences

- The daemon can be started by the GUI without sandbox reinitialisation.
- macOS behavior remains aligned with Linux and Windows process-based daemon hosting.
- ZeroBox cannot be submitted to the Mac App Store without revisiting this decision and introducing an App Sandbox-compatible helper or XPC architecture.
- Users of unsigned downloaded builds may need to explicitly approve the app through macOS security controls. This does not affect local source builds.
- Application data moves from the sandbox container to normal per-user Application Support, Preferences, and temporary directories. Existing installations may need a one-time migration from `~/Library/Containers/org.zxor.zerobox/Data` before a public release.
- The operating system no longer provides an outer file and network sandbox around community plugins. Plugin permissions, virtual storage isolation, path validation, symlink protection, QuickJS host calls, and WASI preopens become security-critical boundaries.
- Old sandbox-container data is not automatically deleted. Migration must be idempotent and preserve the source until successful verification.

## Alternatives considered

### Launch a second application instance through NSWorkspace

This avoids inherited sandbox reinitialisation while retaining App Sandbox, but keeps the daemon as a second full Flutter application instance and adds a macOS-specific native launch bridge.

### Dedicated helper or XPC service

This is the strongest long-term App Sandbox-compatible architecture, but requires another signed target, separate lifecycle and entitlement management, packaging changes, and potentially a different Dart runtime delivery model.

### Disable App Sandbox only in Debug

Rejected because Debug and Release would use different daemon, filesystem, and permission behavior, allowing production-only failures.
