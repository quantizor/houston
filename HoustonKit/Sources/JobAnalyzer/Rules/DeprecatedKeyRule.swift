import Foundation
import Models

/// Flags deprecated launchd plist keys.
public struct DeprecatedKeyRule: AnalysisRule {
    public var name: String { "Deprecated Keys" }

    private static let deprecatedKeys: [(key: String, replacement: String)] = [
        ("OnDemand", "KeepAlive"),
        ("ServiceIPC", "(removed — no replacement needed)"),
        ("HopefullyExitsLast", "(removed — no replacement needed)"),
        ("HopefullyExitsFirst", "(removed — no replacement needed)"),
        ("Debug", "Use os_log or StandardErrorPath for debugging"),
        ("EnableGlobbing", "(removed — globbing no longer supported)"),
    ]

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []

        for entry in Self.deprecatedKeys {
            if plistContents[entry.key] != nil {
                results.append(AnalysisResult(
                    severity: .warning,
                    title: "Deprecated key: \(entry.key)",
                    description: "The key \"\(entry.key)\" is deprecated in modern launchd.",
                    key: entry.key,
                    suggestion: "Replace with \"\(entry.replacement)\"."
                ))
            }
        }

        return results
    }
}
