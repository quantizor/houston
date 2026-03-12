import Foundation
import Models

/// Protocol for pluggable analysis rules that detect misconfigurations in launchd jobs.
public protocol AnalysisRule: Sendable {
    /// Human-readable name for this rule.
    var name: String { get }

    /// Analyze a job and its raw plist contents, returning any issues found.
    func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult]
}
