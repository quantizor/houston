import Foundation
import Models
import LaunchdService

/// Detects misconfigurations and issues in launchd job definitions.
@Observable
public final class JobAnalyzer: @unchecked Sendable {
    /// Analysis results keyed by job label.
    public private(set) var results: [String: [AnalysisResult]] = [:]

    private let rules: [any AnalysisRule]

    /// Creates a new analyzer with the given rules, or all built-in rules if nil.
    public init(rules: [any AnalysisRule]? = nil) {
        self.rules = rules ?? Self.defaultRules
    }

    /// All built-in analysis rules.
    public static var defaultRules: [any AnalysisRule] {
        [
            MissingExecutableRule(),
            PermissionRule(),
            DeprecatedKeyRule(),
            ConflictingKeysRule(),
            LabelRule(),
            CalendarIntervalRule(),
            OutputPathRule(),
            CleanupRule(),
        ]
    }

    /// Analyze a single job, returning all issues found.
    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        let jobResults = rules.flatMap { rule in
            rule.analyze(job: job, plistContents: plistContents)
        }
        results[job.label] = jobResults
        return jobResults
    }

    /// Analyze multiple jobs, returning results keyed by label.
    @discardableResult
    public func analyzeAll(jobs: [(LaunchdJob, [String: Any])]) -> [String: [AnalysisResult]] {
        var allResults: [String: [AnalysisResult]] = [:]
        for (job, plistContents) in jobs {
            let jobResults = analyze(job: job, plistContents: plistContents)
            allResults[job.label] = jobResults
        }
        return allResults
    }

    /// Total number of errors across all analyzed jobs.
    public var errorCount: Int {
        results.values.flatMap { $0 }.filter { $0.severity == .error }.count
    }

    /// Total number of warnings across all analyzed jobs.
    public var warningCount: Int {
        results.values.flatMap { $0 }.filter { $0.severity == .warning }.count
    }
}
