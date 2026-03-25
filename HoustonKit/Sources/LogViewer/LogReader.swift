import Foundation
import Observation
import Models
import PrivilegedHelper

extension LaunchdJob: LoggableJob {}

@Observable @MainActor
public final class LogReader {
    public private(set) var entries: [LogEntry] = []
    public private(set) var isReading: Bool = false
    public var filterText: String = ""
    public var minimumLevel: LogEntry.LogLevel = .debug

    private var stdoutReader: FileTailReader?
    private var stderrReader: FileTailReader?
    private let systemLogReader: any SystemLogQuerying
    private var currentJobLabel: String?
    private var currentExecutablePath: String?

    public var filteredEntries: [LogEntry] {
        entries.filter { entry in
            entry.level >= minimumLevel
            && (filterText.isEmpty || entry.message.localizedCaseInsensitiveContains(filterText))
        }
    }

    public init(helperClient: PrivilegedHelperClient = PrivilegedHelperClient()) {
        self.systemLogReader = SystemLogReader(helperClient: helperClient)
    }

    public init(systemLogReader: any SystemLogQuerying) {
        self.systemLogReader = systemLogReader
    }

    public func loadLogs(for job: some LoggableJob) async {
        isReading = true
        defer { isReading = false }

        entries = []
        currentJobLabel = job.label
        currentExecutablePath = job.executablePath

        // Set up file readers if paths exist
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
            let systemEntries = await systemLogReader.query(label: label, executablePath: currentExecutablePath, since: lastSystemEntry)
            entries.append(contentsOf: systemEntries)
        }
    }

    public func clear() {
        entries = []
    }

    private func readAllSources() async {
        // Read all available sources — file logs and system log
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
            let systemEntries = await systemLogReader.query(label: label, executablePath: currentExecutablePath)
            entries.append(contentsOf: systemEntries)
        }

        entries.sort { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }
}
