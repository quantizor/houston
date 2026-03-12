# Houston — CLAUDE.md

## What is Houston?

Houston is a free, open-source macOS launchd GUI — a democratized alternative to LaunchControl ($16). View, create, edit, enable/disable, and debug launch agents and daemons through a native SwiftUI interface.

## Stack

- Swift 6 / SwiftUI, macOS 26+ (Tahoe)
- Swift Package Manager (HoustonKit local package)
- XPC privileged helper for /Library operations
- No external dependencies beyond Apple frameworks

## Commands

```bash
swift build                    # Build HoustonKit package
swift test                     # Run all package tests
open Houston.xcodeproj         # Open in Xcode
xcodebuild -scheme Houston     # CLI build
```

## Architecture

Single Xcode project with two targets (Houston app + HoustonHelper daemon) and an embedded SPM package (`HoustonKit`). Six modules with explicit dependency graph — no circular dependencies.

```
Models            → (none)             # LaunchdJob, JobStatus, PlistKey
LaunchdService    → Models, PrivilegedHelper  # launchctl executor, plist I/O
PrivilegedHelper  → Models             # XPC client for root operations
JobAnalyzer       → Models, LaunchdService    # Misconfiguration detection
LogViewer         → Models, PrivilegedHelper  # File tail + system log via XPC
PlistEditor       → Models, LaunchdService    # Editor view models
```

## Key Patterns

1. FallbackLaunchctlExecutor — tries direct `Process()` first (correct user context), falls back to XPC helper when sandbox blocks it. Protocol-based (`LaunchctlExecuting`) for testability.
2. @Observable state — single `AppStore` injected via `.environment()`. Fine-grained view updates.
3. NavigationSplitView (3-column) — sidebar (domains/filters), content (job list), detail (editor).
4. Dynamic plist I/O — `NSMutableDictionary` preserves unknown keys; promoted fields use Codable.
5. XPC privileged helper — `HoustonHelper` embedded in app bundle, registered via `SMAppService.daemon()`. Handles launchctl, process management, and system log queries as root.
6. Unified log viewer — tails file-based logs (stdout/stderr from plist paths) AND queries system log via `/usr/bin/log show` NDJSON. All sources combined in one view.
7. Debug/Release entitlements — sandbox off in Debug (direct Process() works), sandbox on in Release (XPC helper required). Helper install only attempted in Release builds.
8. Directory monitoring — `DispatchSource` + `FSEvents` for real-time plist change detection.

## Style Guide

- Clean, professional language
- Minimalist aesthetic in all public-facing surfaces including Makefiles, CLIs, help text, etc.
- Keep the CHANGELOG maintained after completing a large task or fixing a user-reported bug

## Releases

- `make release patch|minor|major` — bumps version, archives, signs, notarizes, creates DMG, publishes GitHub Release
- Every version tag gets a GitHub Release with handwritten, user-facing notes (not `--generate-notes`)
- Release notes use "What's New" for features, "Fixes" for bugs — written from user perspective
- If multiple versions are created in a session, create releases for all of them
- Always verify the latest tag is marked as "latest" (`gh release edit --latest`)
- Known issue: `make release` may fail at `gh release create` if tag isn't pushed; push tag first, then create release manually

## Developer Preferences

- Minimize file creation; edit existing files when possible
- When planning, present 2-3 directions with research-backed opinions
- Proactively ask clarifying questions when there is ambiguity
