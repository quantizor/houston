import Foundation
import Observation
import Models

extension LaunchdJob: LoggableJob {}

@Observable @MainActor
public final class LogReader {
    public private(set) var entries: [LogEntry] = []
    public private(set) var isReading: Bool = false
    public var activeSource: LogEntry.LogSource = .systemLog
    public var filterText: String = ""

    private var stdoutReader: FileTailReader?
    private var stderrReader: FileTailReader?
    private let systemLogReader = SystemLogReader()
    private var currentJobLabel: String?

    public var filteredEntries: [LogEntry] {
        var result = entries.filter { $0.source == activeSource }
        if !filterText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(filterText)
            }
        }
        return result
    }

    public init() {}

    public func loadLogs(for job: some LoggableJob) async {
        isReading = true
        defer { isReading = false }

        entries = []
        currentJobLabel = job.label

        if let stdoutPath = job.standardOutPath {
            stdoutReader = FileTailReader(fileURL: URL(fileURLWithPath: stdoutPath), source: .stdout)
        } else {
            stdoutReader = nil
        }

        if let stderrPath = job.standardErrorPath {
            stderrReader = FileTailReader(fileURL: URL(fileURLWithPath: stderrPath), source: .stderr)
        } else {
            stderrReader = nil
        }

        await readAllSources()
    }

    public func refresh() async {
        isReading = true
        defer { isReading = false }

        if let reader = stdoutReader {
            if let newEntries = try? await reader.readNew() {
                entries.append(contentsOf: newEntries)
            }
        }

        if let reader = stderrReader {
            if let newEntries = try? await reader.readNew() {
                entries.append(contentsOf: newEntries)
            }
        }

        if let label = currentJobLabel {
            let lastSystemEntry = entries.last(where: { $0.source == .systemLog })?.timestamp
            if let systemEntries = try? systemLogReader.query(label: label, since: lastSystemEntry) {
                entries.append(contentsOf: systemEntries)
            }
        }
    }

    public func clear() {
        entries = []
    }

    private func readAllSources() async {
        if let reader = stdoutReader {
            if let fileEntries = try? await reader.readAll() {
                entries.append(contentsOf: fileEntries)
            }
        }

        if let reader = stderrReader {
            if let fileEntries = try? await reader.readAll() {
                entries.append(contentsOf: fileEntries)
            }
        }

        if let label = currentJobLabel {
            if let systemEntries = try? systemLogReader.query(label: label) {
                entries.append(contentsOf: systemEntries)
            }
        }

        entries.sort { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }
}
