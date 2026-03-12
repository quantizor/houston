# Houston

Free, open-source macOS launchd GUI. A democratized alternative to [LaunchControl](https://www.soma-zone.com/LaunchControl/).

Browse, create, edit, enable/disable, and debug launch agents and daemons through a native SwiftUI interface.

## Features

- 3-column layout: domains/filters, job list, detail editor
- Browse all launch agents and daemons across user and system domains
- Create, edit, enable/disable, load/unload jobs
- Plist editor with syntax highlighting and validation
- Privilege escalation via XPC helper (Touch ID on Apple Silicon)
- Real-time directory monitoring for plist changes

## Requirements

- macOS 14+ (Sonoma)
- Swift 6 / Xcode 16+ (for building from source)

## Build and install

```
make build              # Build HoustonKit SPM package
make build-app          # Build the full app via xcodebuild
make build-app-release  # Release build
make install            # Build release and copy to /Applications
make test               # Run all tests
make open               # Open in Xcode
make help               # Show all available commands
```

## Architecture

Single Xcode project with an embedded SPM package (HoustonKit). Six modules:

```
Models            -> (none)
LaunchdService    -> Models
PrivilegedHelper  -> Models
JobAnalyzer       -> Models, LaunchdService
LogViewer         -> Models
PlistEditor       -> Models, LaunchdService
```

Swift 6, SwiftUI, Swift Package Manager, XPC privileged helper for /Library operations. No external dependencies beyond Apple frameworks.

## License

MIT — Made by [Quantizor Ventures](https://quantizor.dev)
