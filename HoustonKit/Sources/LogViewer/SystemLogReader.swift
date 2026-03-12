import Foundation
import PrivilegedHelper

public struct SystemLogReader: Sendable {
    private let helperClient: PrivilegedHelperClient

    public init(helperClient: PrivilegedHelperClient = PrivilegedHelperClient()) {
        self.helperClient = helperClient
    }

    public func query(label: String, executablePath: String? = nil, since: Date? = nil, limit: Int = 500) async -> [LogEntry] {
        // Match by subsystem (apps that use label as subsystem) or process name (executable basename)
        var clauses = ["subsystem == '\(label)'"]

        if let path = executablePath {
            let processName = (path as NSString).lastPathComponent
            clauses.append("process == '\(processName)'")
        }

        let predicate = clauses.joined(separator: " OR ")
        return await query(predicate: predicate, since: since, limit: limit)
    }

    public func query(predicate: String, since: Date? = nil, limit: Int = 500) async -> [LogEntry] {
        let sinceDate = since ?? Date(timeIntervalSinceNow: -3600)
        let interval = Date().timeIntervalSince(sinceDate)

        // Try direct `log show` via Process() first (works outside sandbox)
        if let entries = await queryDirectProcess(predicate: predicate, sinceInterval: interval, limit: limit) {
            return entries
        }

        // Fall back to XPC helper (required in sandbox where Process() is blocked)
        return await queryViaXPC(predicate: predicate, sinceInterval: interval, limit: limit)
    }

    // MARK: - Direct Process() (no sandbox)

    private func queryDirectProcess(predicate: String, sinceInterval: Double, limit: Int) async -> [LogEntry]? {
        let seconds = max(1, Int(sinceInterval))
        let args = ["show", "--predicate", predicate, "--last", "\(seconds)s", "--style", "ndjson", "--info", "--debug"]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = args

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: self.parseNDJSON(output, limit: limit))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: nil) // Process() blocked (sandbox)
            }
        }
    }

    // MARK: - XPC helper fallback (sandboxed)

    private func queryViaXPC(predicate: String, sinceInterval: Double, limit: Int) async -> [LogEntry] {
        do {
            let output = try await helperClient.querySystemLog(
                predicate: predicate,
                sinceInterval: sinceInterval,
                limit: limit
            )
            return parseNDJSON(output, limit: limit)
        } catch {
            return [
                LogEntry(
                    timestamp: Date(),
                    message: "Unable to access system log: \(error.localizedDescription)",
                    source: .systemLog,
                    level: .warning
                )
            ]
        }
    }

    // MARK: - NDJSON parsing

    private func parseNDJSON(_ output: String, limit: Int) -> [LogEntry] {
        var entries: [LogEntry] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            if entries.count >= limit { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.hasPrefix("{") else { continue }

            guard let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Skip activity/signpost events — only show actual log messages
            let eventType = json["eventType"] as? String
            guard eventType == "logEvent" else { continue }

            let message = json["eventMessage"] as? String ?? json["composedMessage"] as? String ?? ""
            guard !message.isEmpty else { continue }

            let timestamp = parseTimestamp(json["timestamp"] as? String)
            let level = mapLogLevel(json["messageType"] as? String)

            entries.append(LogEntry(
                timestamp: timestamp,
                message: message,
                source: .systemLog,
                level: level
            ))
        }

        return entries
    }

    private func parseTimestamp(_ str: String?) -> Date? {
        guard let str else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str)
    }

    private func mapLogLevel(_ type: String?) -> LogEntry.LogLevel {
        switch type?.lowercased() {
        case "debug": return .debug
        case "info": return .info
        case "default": return .notice
        case "error": return .error
        case "fault": return .fault
        default: return .info
        }
    }
}
