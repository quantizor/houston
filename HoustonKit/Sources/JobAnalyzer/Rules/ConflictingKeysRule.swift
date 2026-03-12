import Foundation
import Models

/// Detects conflicting key combinations in launchd plist files.
public struct ConflictingKeysRule: AnalysisRule {
    public var name: String { "Conflicting Keys" }

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []

        // KeepAlive: true + RunAtLoad: false
        if let keepAlive = plistContents["KeepAlive"] as? Bool, keepAlive,
           let runAtLoad = plistContents["RunAtLoad"] as? Bool, !runAtLoad {
            results.append(AnalysisResult(
                severity: .warning,
                title: "KeepAlive without RunAtLoad",
                description: "KeepAlive is true but RunAtLoad is false. The job won't start until triggered but is expected to stay alive.",
                key: "KeepAlive",
                suggestion: "Set RunAtLoad to true, or use KeepAlive with specific conditions."
            ))
        }

        // StartInterval + StartCalendarInterval (both present)
        if plistContents["StartInterval"] != nil && plistContents["StartCalendarInterval"] != nil {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Conflicting scheduling keys",
                description: "Both StartInterval and StartCalendarInterval are set. Only one scheduling mechanism should be used.",
                key: "StartInterval",
                suggestion: "Remove one of StartInterval or StartCalendarInterval."
            ))
        }

        return results
    }
}
