import Foundation

public struct AnalysisResult: Identifiable, Sendable {
    public let id: UUID
    public let severity: Severity
    public let title: String
    public let description: String
    public let key: String?
    public let suggestion: String?

    public enum Severity: String, Sendable, CaseIterable, Comparable {
        case error
        case warning
        case info

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.info, .warning, .error]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }

    public init(
        severity: Severity,
        title: String,
        description: String,
        key: String? = nil,
        suggestion: String? = nil
    ) {
        self.id = UUID()
        self.severity = severity
        self.title = title
        self.description = description
        self.key = key
        self.suggestion = suggestion
    }
}
