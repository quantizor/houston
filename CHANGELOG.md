# Changelog

All notable changes to Houston are documented here.

## [Unreleased]

### Added
- Design token system (DesignTokens.swift) — centralized color, symbol, and label extensions for JobStatus, AnalysisResult.Severity, LogEntry.LogLevel, and ValidationSeverity
- Reusable `StatusPill` and `TagBadge` components replacing duplicated badge markup
- Release pipeline: `make release` for local signed+notarized DMG builds
- GitHub Actions release workflow triggered by version tags
- Toast notification system for action feedback (ToastView.swift)
  - Success toasts after load, unload, enable, disable, start, kill, delete, save
  - Error toasts replacing the old modal alert dialog
  - Info toasts for clipboard copy actions (Copy PID, Copy Label)
  - Auto-dismiss after 2.5s with spring animation
  - Liquid Glass `.glassEffect()` styling on macOS 26
- Sidebar vibrancy via `.listStyle(.sidebar)` (letting macOS handle translucency)

### Fixed
- Warning severity color using `.yellow` (invisible on light backgrounds) — now `.orange` everywhere
- Log level colors inconsistent between LogPreview and LogViewerView — unified via shared extension
- Dark mode: `.black.opacity(0.03)` background invisible — replaced with `.quaternary.opacity(0.3)`

### Changed
- All hardcoded font sizes (`.system(size: 10)`, `NSFont(ofSize: 13)`) replaced with semantic Dynamic Type tokens
- Deduplicated status color/symbol/label logic from 3 independent implementations to shared extensions
- Badge padding standardized across all views (6/2 for pills, 6/2 for tags)
- Error feedback migrated from blocking `.alert()` dialog to non-blocking toast overlay
- Removed `.navigationSplitViewStyle(.balanced)` then restored it (no effect on translucency)

### Removed
- `errorMessage` property from AppStore (replaced by unified toast system)
