# Houston — CLAUDE.md

## What is Houston?

Houston is a free, open-source macOS launchd GUI — a democratized alternative to LaunchControl ($16). View, create, edit, enable/disable, and debug launch agents and daemons through a native SwiftUI interface.

## Stack

- Swift 6 / SwiftUI, macOS 14+ (Sonoma)
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

Single Xcode project with embedded SPM package (`HoustonKit`). Six modules with explicit dependency graph — no circular dependencies.

```
Models            → (none)        # LaunchdJob, JobStatus, PlistKey
LaunchdService    → Models        # launchctl executor, plist I/O
PrivilegedHelper  → Models        # XPC client for root operations
JobAnalyzer       → Models, LaunchdService  # Misconfiguration detection
LogViewer         → Models        # File tail + OSLog reading
PlistEditor       → Models, LaunchdService  # Editor view models
```

## Key Patterns

1. **launchctl via Process** — no private APIs. Modern subcommands: `bootstrap`/`bootout`/`enable`/`disable`.
2. **@Observable state** — single `AppStore` injected via `.environment()`. Fine-grained view updates.
3. **NavigationSplitView (3-column)** — sidebar (domains/filters), content (job list), detail (editor).
4. **Dynamic plist I/O** — `NSMutableDictionary` preserves unknown keys; promoted fields use Codable.
5. **Privilege escalation** — XPC helper registered via `SMAppService.daemon()`, validates caller signature.
6. **Directory monitoring** — `DispatchSource` + `FSEvents` for real-time plist change detection.

## Style Guide

- Clean, professional language
- Minimalist aesthetic in all public-facing surfaces including Makefiles, CLIs, help text, etc.
- Keep the CHANGELOG maintained after completing a large task or fixing a user-reported bug

## Developer Preferences

- Minimize file creation; edit existing files when possible
- When planning, present 2-3 directions with research-backed opinions
- Proactively ask clarifying questions when there is ambiguity
