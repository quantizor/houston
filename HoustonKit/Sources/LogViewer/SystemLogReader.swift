import Foundation
import OSLog

public struct SystemLogReader: Sendable {
    public init() {}

    public func query(label: String, since: Date? = nil, limit: Int = 500) throws -> [LogEntry] {
        let predicate = "subsystem == '\(label)' OR process == '\(label)'"
        return try query(predicate: predicate, since: since, limit: limit)
    }

    public func query(predicate: String, since: Date? = nil, limit: Int = 500) throws -> [LogEntry] {
        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .system)
        } catch {
            return [
                LogEntry(
                    timestamp: Date(),
                    message: "Unable to access system log: \(error.localizedDescription). Elevated privileges may be required.",
                    source: .systemLog,
                    level: .warning
                )
            ]
        }

        let sinceDate = since ?? Date(timeIntervalSinceNow: -3600)
        let position = store.position(date: sinceDate)
        let nsPredicate = NSPredicate(format: predicate)

        var entries: [LogEntry] = []
        do {
            let logEntries = try store.getEntries(at: position, matching: nsPredicate)
            for entry in logEntries {
                if entries.count >= limit { break }
                let level = logLevel(from: entry)
                entries.append(
                    LogEntry(
                        timestamp: entry.date,
                        message: entry.composedMessage,
                        source: .systemLog,
                        level: level
                    )
                )
            }
        } catch {
            return [
                LogEntry(
                    timestamp: Date(),
                    message: "Log query failed: \(error.localizedDescription)",
                    source: .systemLog,
                    level: .warning
                )
            ]
        }

        return entries
    }

    private func logLevel(from entry: OSLogEntry) -> LogEntry.LogLevel {
        guard let logEntry = entry as? OSLogEntryLog else {
            return .info
        }
        switch logEntry.level {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .notice
        case .error: return .error
        case .fault: return .fault
        default: return .info
        }
    }
}
