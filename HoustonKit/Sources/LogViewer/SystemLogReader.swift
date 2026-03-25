import Foundation
import PrivilegedHelper

public protocol SystemLogQuerying: Sendable {
    func query(label: String, executablePath: String?, since: Date?, limit: Int) async -> [LogEntry]
    func query(predicate: String, since: Date?, limit: Int) async -> [LogEntry]
}

extension SystemLogQuerying {
    public func query(label: String, executablePath: String? = nil, since: Date? = nil, limit: Int = 500) async -> [LogEntry] {
        await query(label: label, executablePath: executablePath, since: since, limit: limit)
    }
    public func query(predicate: String, since: Date? = nil, limit: Int = 500) async -> [LogEntry] {
        await query(predicate: predicate, since: since, limit: limit)
    }
}

public struct SystemLogReader: SystemLogQuerying, Sendable {
    private let helperClient: PrivilegedHelperClient

    private nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init(helperClient: PrivilegedHelperClient = PrivilegedHelperClient()) {
        self.helperClient = helperClient
    }

    public func query(label: String, executablePath: String? = nil, since: Date? = nil, limit: Int = 500) async -> [LogEntry] {
        let escapedLabel = label.replacingOccurrences(of: "'", with: "\\'")
        var clauses = ["subsystem == '\(escapedLabel)'"]

        if let path = executablePath {
            let processName = (path as NSString).lastPathComponent
            let escapedProcess = processName.replacingOccurrences(of: "'", with: "\\'")
            clauses.append("process == '\(escapedProcess)'")
            // Match by full executable path in senderImagePath (catches logs even when
            // subsystem/process don't match the label, common for system daemons)
            let escapedPath = path.replacingOccurrences(of: "'", with: "\\'")
            clauses.append("senderImagePath == '\(escapedPath)'")
        }

        // Many Apple daemons log under their short name (last label component)
        // e.g., com.apple.metadata.mds logs as process "mds"
        let shortName = label.split(separator: ".").last.map(String.init)
        if let shortName, shortName.count > 2 {
            let escapedShort = shortName.replacingOccurrences(of: "'", with: "\\'")
            if !clauses.contains(where: { $0.contains("process == '\(escapedShort)'") }) {
                clauses.append("process == '\(escapedShort)'")
            }
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

    func parseNDJSON(_ output: String, limit: Int) -> [LogEntry] {
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

    func parseTimestamp(_ str: String?) -> Date? {
        guard let str else { return nil }
        return Self.isoFormatter.date(from: str)
    }

    func mapLogLevel(_ type: String?) -> LogEntry.LogLevel {
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
