import Foundation

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date?
    public let message: String
    public let source: LogSource
    public let level: LogLevel

    public init(timestamp: Date? = nil, message: String, source: LogSource, level: LogLevel = .info) {
        self.id = UUID()
        self.timestamp = timestamp
        self.message = message
        self.source = source
        self.level = level
    }

    public enum LogSource: String, CaseIterable, Sendable {
        case stdout
        case stderr
        case systemLog
    }

    public enum LogLevel: String, CaseIterable, Comparable, Sendable {
        case debug, info, notice, warning, error, fault

        private var severity: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .notice: return 2
            case .warning: return 3
            case .error: return 4
            case .fault: return 5
            }
        }

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.severity < rhs.severity
        }
    }
}
