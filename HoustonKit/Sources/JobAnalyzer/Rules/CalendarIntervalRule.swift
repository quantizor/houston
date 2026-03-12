import Foundation
import Models

/// Validates StartCalendarInterval values are within valid ranges.
public struct CalendarIntervalRule: AnalysisRule {
    public var name: String { "Calendar Interval Validation" }

    private static let validRanges: [(key: String, range: ClosedRange<Int>)] = [
        ("Month", 1...12),
        ("Day", 1...31),
        ("Weekday", 0...7),
        ("Hour", 0...23),
        ("Minute", 0...59),
    ]

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        guard let calendarInterval = plistContents["StartCalendarInterval"] else {
            return []
        }

        // StartCalendarInterval can be a single dict or an array of dicts.
        var intervals: [[String: Any]] = []
        if let single = calendarInterval as? [String: Any] {
            intervals = [single]
        } else if let array = calendarInterval as? [[String: Any]] {
            intervals = array
        } else {
            return []
        }

        var results: [AnalysisResult] = []

        for (index, interval) in intervals.enumerated() {
            let prefix = intervals.count > 1 ? "Entry \(index + 1): " : ""
            for (key, validRange) in Self.validRanges {
                if let value = interval[key] as? Int {
                    if !validRange.contains(value) {
                        results.append(AnalysisResult(
                            severity: .error,
                            title: "\(prefix)\(key) out of range",
                            description: "\(key) value \(value) is outside the valid range \(validRange.lowerBound)–\(validRange.upperBound).",
                            key: "StartCalendarInterval",
                            suggestion: "Set \(key) to a value between \(validRange.lowerBound) and \(validRange.upperBound)."
                        ))
                    }
                }
            }
        }

        return results
    }
}
