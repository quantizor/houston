# Changelog

All notable changes to Houston are documented here.

## [1.1.0] — 2026-03-25

### Added
- **Launch Angels** — new macOS 26 domain category (`/System/Library/LaunchAngels/`) displayed in sidebar as read-only
- **System domains** — view Apple's system agents and daemons (`/System/Library/LaunchAgents/`, `/System/Library/LaunchDaemons/`) as read-only
- **Apple service descriptions** — all 870 system services on macOS 26 have human-readable descriptions in the Identity section, verified against actual plists on disk
- **Job diagnostics** — plain-English explanations of exit codes (sysexits.h, signals) and synthesized diagnosis ("why isn't this running?") displayed in the status header
- **Schedule preview** — jobs with StartInterval or StartCalendarInterval show human-readable schedule and next fire time in both the diagnostics header and the Standard tab Scheduling section
- **Field tooltips** — hover over any field in the Standard or Expert tab to see what it does, powered by descriptions for all 43 plist keys
- **System dashboard** — landing page shows health summary and a clickable list of jobs that need attention (failed exits with explanations, error states), replacing the previous redundant stats display
- **Reveal in Finder** button in the detail toolbar for quick plist file access
- **Toast notifications** for action feedback (success, error, info) with auto-dismiss and Liquid Glass styling
- Design token system — centralized color, symbol, and label extensions replacing 3 independent implementations
- Reusable `StatusPill` and `TagBadge` components
- **Job creation templates** — choose from Blank, Run Script, Background Daemon, Scheduled Task, or File Watcher when creating a new job, with pre-filled settings
- **StartCalendarInterval editor** — edit calendar-based scheduling (month, day, weekday, hour, minute) directly in the Standard tab Scheduling section
- **Environment variables editor** — add, edit, and remove environment variables directly in the Standard tab with key-value fields
- **Log severity filter** — filter log viewer by minimum severity level (debug/info/notice/warning/error/fault) via a dropdown picker
- 5 new plist keys: `AssociatedBundleIdentifiers`, `EnablePressuredExit`, `EnableTransactions`, `LaunchEvents`, `MaterializeDatalessFiles`
- 4 new deprecated key warnings: `HopefullyExitsLast`, `HopefullyExitsFirst`, `Debug`, `EnableGlobbing`
- `ProcessType` promoted as a first-class field in the job editor
- SMAppService error enrichment with user-facing guidance pointing to System Settings
- Forks, execs, and active count surfaced in runtime details row
- Hover states on job rows, key rows, and log preview header
- Sidebar vibrancy via `.listStyle(.sidebar)`
- Release pipeline: `make release` for local signed+notarized DMG builds
- GitHub Actions release workflow triggered by version tags

### Changed
- **XPC migration** — replaced `NSXPCConnection`/`@objc protocol` with Swift `XPCSession`/`XPCListener` and `Codable` message types
- **XPC security** — `XPCPeerRequirement.isFromSameTeam()` validates caller code signing identity
- **Liquid Glass** — `.buttonStyle(.glass)` and `.glassEffect()` adopted throughout
- Bootstrap/bootout argument validation — plist paths validated against allowed directories
- Log query limit enforcement — NDJSON output truncated server-side to requested limit
- XML syntax colors use semantic `NSColor.system*` colors (adapts to any appearance)
- Control sizes standardized: `.small` on toolbar utility buttons, `.large` on primary sheet actions
- DirectoryMonitor watches `.write`, `.delete`, `.rename`, `.attrib` (was only `.write`)
- Cached `ISO8601DateFormatter` in SystemLogReader (was allocating per NDJSON line)
- Escaped single quotes in log query predicates (prevents breakage with labels like `O'Brien`)
- Helper version read from `Bundle.main` instead of hardcoded string
- All hardcoded font sizes replaced with semantic Dynamic Type tokens
- Error feedback migrated from blocking `.alert()` dialog to non-blocking toast overlay
- Package.swift platform bumped to macOS 26 (swift-tools-version 6.2)

### Fixed
- Clearing a plist field (setting to nil) now removes the key from disk (was silently preserved)
- Deprecated `NSApplication.shared.activate(ignoringOtherApps:)` replaced with `.activate()`
- Search bar no longer disappears when filter matches zero jobs
- Search now matches display name, vendor prefix, executable path, and Apple service descriptions — typing "Spotlight" finds `com.apple.metadata.mds`
- **Cmd+F** focuses the search field; **Escape** clears search text or defocuses
- Warning severity color using `.yellow` (invisible on light backgrounds) — now `.orange` everywhere
- Log level colors unified between LogPreview and LogViewerView via shared extension
- Dark mode: `.black.opacity(0.03)` background invisible — replaced with `.quaternary.opacity(0.3)`
- Read-only system domain jobs now disable editor controls while keeping the form scrollable, with a "system service" indicator bar at the bottom
- Display name now shows the meaningful service name (e.g. "security", "Dock", "Siri") instead of generic "agent" or "daemon" for every row
- Dashboard "needs attention" no longer counts Apple system services with normal exit codes (SIGKILL, SIGTERM, SIGINT) — only user-actionable jobs are shown
- `launchctlDomain` corrected for system agents and global agents — now uses `gui/<uid>` (user session) instead of `system`, fixing missing runtime stats
- Detail view loading indicator while plist data is being read
- Menu bar widget version string now reads from bundle instead of hardcoded "v0.1.0"

### Removed
- `CAuthHelper` module (unused dead code using deprecated `AuthorizationExecuteWithPrivileges`)
- `HelperProtocol.swift` (replaced by Codable message enums)
- `SMAuthorizedClients` from helper Info.plist (vestigial SMJobBless key)
- `errorMessage` property from AppStore (replaced by toast system)
