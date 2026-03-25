import Testing
import Foundation
@testable import LogViewer

@Suite("LogEntry Tests")
struct LogEntryTests {
    @Test("LogEntry creation with defaults")
    func creation() {
        let entry = LogEntry(message: "Hello", source: .stdout)
        #expect(entry.message == "Hello")
        #expect(entry.source == .stdout)
        #expect(entry.level == .info)
        #expect(entry.timestamp == nil)
    }

    @Test("LogEntry creation with all fields")
    func creationFull() {
        let now = Date()
        let entry = LogEntry(timestamp: now, message: "Error occurred", source: .stderr, level: .error)
        #expect(entry.timestamp == now)
        #expect(entry.message == "Error occurred")
        #expect(entry.source == .stderr)
        #expect(entry.level == .error)
    }

    @Test("LogLevel comparison follows severity ordering")
    func levelComparison() {
        #expect(LogEntry.LogLevel.debug < LogEntry.LogLevel.info)
        #expect(LogEntry.LogLevel.info < LogEntry.LogLevel.notice)
        #expect(LogEntry.LogLevel.notice < LogEntry.LogLevel.warning)
        #expect(LogEntry.LogLevel.warning < LogEntry.LogLevel.error)
        #expect(LogEntry.LogLevel.error < LogEntry.LogLevel.fault)
        #expect(!(LogEntry.LogLevel.fault < LogEntry.LogLevel.debug))
    }

    @Test("LogLevel equality")
    func levelEquality() {
        #expect(LogEntry.LogLevel.info == LogEntry.LogLevel.info)
        #expect(LogEntry.LogLevel.debug != LogEntry.LogLevel.fault)
    }

    @Test("LogSource cases")
    func sourceCases() {
        let allCases = LogEntry.LogSource.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.stdout))
        #expect(allCases.contains(.stderr))
        #expect(allCases.contains(.systemLog))
    }
}

@Suite("FileTailReader Tests")
struct FileTailReaderTests {
    private func createTempFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("houston_test_\(UUID().uuidString).log")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @Test("Read entire file")
    func readAll() async throws {
        let url = try createTempFile(content: "line 1\nline 2\nline 3\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = FileTailReader(fileURL: url)
        let entries = try await reader.readAll()
        #expect(entries.count == 3)
        #expect(entries[0].message == "line 1")
        #expect(entries[1].message == "line 2")
        #expect(entries[2].message == "line 3")
        #expect(entries[0].source == .stdout)
    }

    @Test("Read new content after append")
    func readNew() async throws {
        let url = try createTempFile(content: "initial line\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = FileTailReader(fileURL: url)
        let initial = try await reader.readAll()
        #expect(initial.count == 1)

        let handle = try FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()
        handle.write("appended line\n".data(using: .utf8)!)
        try handle.close()

        let newEntries = try await reader.readNew()
        #expect(newEntries.count == 1)
        #expect(newEntries[0].message == "appended line")
    }

    @Test("Read nonexistent file returns empty")
    func readMissingFile() async throws {
        let url = URL(fileURLWithPath: "/tmp/houston_nonexistent_\(UUID().uuidString).log")
        let reader = FileTailReader(fileURL: url)
        let entries = try await reader.readAll()
        #expect(entries.isEmpty)
    }

    @Test("Reset causes full re-read")
    func reset() async throws {
        let url = try createTempFile(content: "line 1\nline 2\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = FileTailReader(fileURL: url)
        _ = try await reader.readAll()
        await reader.reset()
        let reread = try await reader.readAll()
        #expect(reread.count == 2)
    }

    @Test("Stderr source sets error level")
    func stderrSource() async throws {
        let url = try createTempFile(content: "error msg\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = FileTailReader(fileURL: url, source: .stderr)
        let entries = try await reader.readAll()
        #expect(entries.count == 1)
        #expect(entries[0].source == .stderr)
        #expect(entries[0].level == .error)
    }
}

struct MockJob: LoggableJob {
    var label: String
    var executablePath: String?
    var standardOutPath: String?
    var standardErrorPath: String?
}

struct NoOpSystemLogReader: SystemLogQuerying {
    func query(label: String, executablePath: String?, since: Date?, limit: Int) async -> [LogEntry] { [] }
    func query(predicate: String, since: Date?, limit: Int) async -> [LogEntry] { [] }
}

@Suite("LogReader Tests")
@MainActor
struct LogReaderTests {
    @Test("LogReader can be initialized")
    func canInit() {
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        #expect(reader.entries.isEmpty)
        #expect(reader.isReading == false)
        #expect(reader.filterText.isEmpty)
    }

    @Test("Clear removes all entries")
    func clear() {
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        reader.clear()
        #expect(reader.entries.isEmpty)
    }

    @Test("Loads file-based logs when paths are set")
    func loadFileLogs() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let stdoutURL = tempDir.appendingPathComponent("houston_test_stdout_\(UUID().uuidString).log")
        try "stdout line\n".write(to: stdoutURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: stdoutURL) }

        let stderrURL = tempDir.appendingPathComponent("houston_test_stderr_\(UUID().uuidString).log")
        try "stderr line\n".write(to: stderrURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: stderrURL) }

        let job = MockJob(
            label: "com.test.logviewer",
            standardOutPath: stdoutURL.path,
            standardErrorPath: stderrURL.path
        )

        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        let entries = reader.filteredEntries
        #expect(entries.count == 2)
        #expect(entries.contains { $0.source == .stdout })
        #expect(entries.contains { $0.source == .stderr })
    }

    @Test("Filtered entries by text")
    func filterByText() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("houston_test_filter_\(UUID().uuidString).log")
        try "hello world\ngoodbye world\nhello again\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.filter", standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        reader.filterText = "hello"
        let filtered = reader.filteredEntries
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.message.contains("hello") })
    }
}

@Suite("DirectoryMonitor Tests")
struct DirectoryMonitorTests {
    @Test("DirectoryMonitor can be initialized")
    func canInit() {
        let url = FileManager.default.temporaryDirectory
        let monitor = DirectoryMonitor(url: url)
        #expect(monitor != nil)
    }

    @Test("DirectoryMonitor start and stop")
    func startStop() {
        let url = FileManager.default.temporaryDirectory
        let monitor = DirectoryMonitor(url: url)
        monitor.start(onChange: {})
        monitor.stop()
    }
}

@Suite("SystemLogReader Tests")
struct SystemLogReaderTests {
    let reader = SystemLogReader()

    // MARK: - Initialization

    @Test("SystemLogReader can be initialized")
    func canInit() {
        #expect(reader != nil)
    }

    // MARK: - parseNDJSON

    @Test("parseNDJSON with valid log entries")
    func parseValidEntries() {
        let ndjson = """
        {"eventType":"logEvent","eventMessage":"Hello world","messageType":"Default","timestamp":"2026-03-24T10:00:00.000000Z"}
        {"eventType":"logEvent","eventMessage":"Another message","messageType":"Info","timestamp":"2026-03-24T10:00:01.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 2)
        #expect(entries[0].message == "Hello world")
        #expect(entries[1].message == "Another message")
        #expect(entries[0].source == .systemLog)
        #expect(entries[1].source == .systemLog)
    }

    @Test("parseNDJSON maps log levels correctly")
    func parseLevelMapping() {
        let ndjson = """
        {"eventType":"logEvent","eventMessage":"debug msg","messageType":"Debug","timestamp":"2026-03-24T10:00:00.000000Z"}
        {"eventType":"logEvent","eventMessage":"info msg","messageType":"Info","timestamp":"2026-03-24T10:00:01.000000Z"}
        {"eventType":"logEvent","eventMessage":"default msg","messageType":"Default","timestamp":"2026-03-24T10:00:02.000000Z"}
        {"eventType":"logEvent","eventMessage":"error msg","messageType":"Error","timestamp":"2026-03-24T10:00:03.000000Z"}
        {"eventType":"logEvent","eventMessage":"fault msg","messageType":"Fault","timestamp":"2026-03-24T10:00:04.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 5)
        #expect(entries[0].level == .debug)
        #expect(entries[1].level == .info)
        #expect(entries[2].level == .notice)
        #expect(entries[3].level == .error)
        #expect(entries[4].level == .fault)
    }

    @Test("parseNDJSON with empty input")
    func parseEmptyInput() {
        let entries = reader.parseNDJSON("", limit: 500)
        #expect(entries.isEmpty)
    }

    @Test("parseNDJSON skips malformed JSON lines")
    func parseMalformedLines() {
        let ndjson = """
        {"eventType":"logEvent","eventMessage":"good line","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        {this is not valid json}
        {"eventType":"logEvent","eventMessage":"another good line","messageType":"Error","timestamp":"2026-03-24T10:00:01.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 2)
        #expect(entries[0].message == "good line")
        #expect(entries[1].message == "another good line")
    }

    @Test("parseNDJSON skips non-JSON header lines from log show")
    func parseSkipsHeaders() {
        let ndjson = """
        Filtering the log data using "subsystem == 'com.example.test'"
        Timestamp                       Thread     Type        Activity             PID    TTL
        {"eventType":"logEvent","eventMessage":"actual entry","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 1)
        #expect(entries[0].message == "actual entry")
    }

    @Test("parseNDJSON respects limit parameter")
    func parseLimitTruncates() {
        let ndjson = """
        {"eventType":"logEvent","eventMessage":"msg 1","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        {"eventType":"logEvent","eventMessage":"msg 2","messageType":"Info","timestamp":"2026-03-24T10:00:01.000000Z"}
        {"eventType":"logEvent","eventMessage":"msg 3","messageType":"Info","timestamp":"2026-03-24T10:00:02.000000Z"}
        {"eventType":"logEvent","eventMessage":"msg 4","messageType":"Info","timestamp":"2026-03-24T10:00:03.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 2)
        #expect(entries.count == 2)
        #expect(entries[0].message == "msg 1")
        #expect(entries[1].message == "msg 2")
    }

    @Test("parseNDJSON skips non-logEvent entries")
    func parseSkipsNonLogEvents() {
        let ndjson = """
        {"eventType":"activityCreateEvent","eventMessage":"activity created","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        {"eventType":"logEvent","eventMessage":"real log","messageType":"Info","timestamp":"2026-03-24T10:00:01.000000Z"}
        {"eventType":"signpostEvent","eventMessage":"signpost","messageType":"Info","timestamp":"2026-03-24T10:00:02.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 1)
        #expect(entries[0].message == "real log")
    }

    @Test("parseNDJSON skips entries with empty messages")
    func parseSkipsEmptyMessages() {
        let ndjson = """
        {"eventType":"logEvent","eventMessage":"","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        {"eventType":"logEvent","eventMessage":"has content","messageType":"Info","timestamp":"2026-03-24T10:00:01.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 1)
        #expect(entries[0].message == "has content")
    }

    @Test("parseNDJSON uses composedMessage as fallback")
    func parseComposedMessageFallback() {
        let ndjson = """
        {"eventType":"logEvent","composedMessage":"fallback message","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 1)
        #expect(entries[0].message == "fallback message")
    }

    @Test("parseNDJSON handles entries without eventType")
    func parseNoEventType() {
        let ndjson = """
        {"eventMessage":"no event type","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}
        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.isEmpty)
    }

    @Test("parseNDJSON with whitespace-only lines")
    func parseWhitespaceLines() {
        let ndjson = """


        {"eventType":"logEvent","eventMessage":"after whitespace","messageType":"Info","timestamp":"2026-03-24T10:00:00.000000Z"}

        """
        let entries = reader.parseNDJSON(ndjson, limit: 500)
        #expect(entries.count == 1)
        #expect(entries[0].message == "after whitespace")
    }

    // MARK: - parseTimestamp

    @Test("parseTimestamp with valid ISO8601 date")
    func parseValidTimestamp() {
        let date = reader.parseTimestamp("2026-03-24T10:30:00.123456Z")
        #expect(date != nil)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 24)
    }

    @Test("parseTimestamp with nil returns nil")
    func parseNilTimestamp() {
        let date = reader.parseTimestamp(nil)
        #expect(date == nil)
    }

    @Test("parseTimestamp with invalid string returns nil")
    func parseInvalidTimestamp() {
        let date = reader.parseTimestamp("not a date")
        #expect(date == nil)
    }

    // MARK: - mapLogLevel

    @Test("mapLogLevel maps all known types")
    func mapAllLevels() {
        #expect(reader.mapLogLevel("Debug") == .debug)
        #expect(reader.mapLogLevel("debug") == .debug)
        #expect(reader.mapLogLevel("Info") == .info)
        #expect(reader.mapLogLevel("info") == .info)
        #expect(reader.mapLogLevel("Default") == .notice)
        #expect(reader.mapLogLevel("default") == .notice)
        #expect(reader.mapLogLevel("Error") == .error)
        #expect(reader.mapLogLevel("error") == .error)
        #expect(reader.mapLogLevel("Fault") == .fault)
        #expect(reader.mapLogLevel("fault") == .fault)
    }

    @Test("mapLogLevel returns info for nil")
    func mapNilLevel() {
        #expect(reader.mapLogLevel(nil) == .info)
    }

    @Test("mapLogLevel returns info for unknown type")
    func mapUnknownLevel() {
        #expect(reader.mapLogLevel("Unknown") == .info)
        #expect(reader.mapLogLevel("critical") == .info)
    }

}

// MARK: - Extended LogReader Tests

@Suite("LogReader Extended Tests")
@MainActor
struct LogReaderExtendedTests {
    private func createTempFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("houston_test_\(UUID().uuidString).log")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @Test("LogReader loadLogs with no stdout or stderr paths")
    func loadLogsNoPaths() async {
        let job = MockJob(label: "com.test.nopaths", executablePath: nil, standardOutPath: nil, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)
        // Should not crash; entries may include system log results
        #expect(reader.isReading == false)
    }

    @Test("LogReader loadLogs with only stdout")
    func loadLogsStdoutOnly() async throws {
        let url = try createTempFile(content: "stdout only\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.stdoutonly", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        let stdoutEntries = reader.entries.filter { $0.source == .stdout }
        #expect(stdoutEntries.count == 1)
        #expect(stdoutEntries[0].message == "stdout only")
    }

    @Test("LogReader loadLogs with only stderr")
    func loadLogsStderrOnly() async throws {
        let url = try createTempFile(content: "stderr only\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.stderronly", executablePath: nil, standardOutPath: nil, standardErrorPath: url.path)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        let stderrEntries = reader.entries.filter { $0.source == .stderr }
        #expect(stderrEntries.count == 1)
        #expect(stderrEntries[0].message == "stderr only")
    }

    @Test("LogReader refresh after initial load")
    func refreshAfterLoad() async throws {
        let url = try createTempFile(content: "initial\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.refresh", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        let initialStdout = reader.entries.filter { $0.source == .stdout }
        #expect(initialStdout.count == 1)

        // Append new content
        let handle = try FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()
        handle.write("appended\n".data(using: .utf8)!)
        try handle.close()

        await reader.refresh()

        let allStdout = reader.entries.filter { $0.source == .stdout }
        #expect(allStdout.count == 2)
        #expect(allStdout[1].message == "appended")
    }

    @Test("LogReader clear after loading entries")
    func clearAfterLoad() async throws {
        let url = try createTempFile(content: "line 1\nline 2\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.clear", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        #expect(!reader.entries.isEmpty)
        reader.clear()
        #expect(reader.entries.isEmpty)
        #expect(reader.filteredEntries.isEmpty)
    }

    @Test("LogReader filteredEntries returns all when filter is empty")
    func filteredEntriesNoFilter() async throws {
        let url = try createTempFile(content: "aaa\nbbb\nccc\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.nofilter", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        reader.filterText = ""
        let stdoutEntries = reader.filteredEntries.filter { $0.source == .stdout }
        #expect(stdoutEntries.count == 3)
    }

    @Test("LogReader filteredEntries is case-insensitive")
    func filteredEntriesCaseInsensitive() async throws {
        let url = try createTempFile(content: "Hello World\nhello there\nGOODBYE\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.casefilter", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        reader.filterText = "HELLO"
        let filtered = reader.filteredEntries
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.message.lowercased().contains("hello") })
    }

    @Test("LogReader filteredEntries respects minimumLevel")
    func filteredEntriesByLevel() async throws {
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        // Inject entries directly via loadLogs with a file containing lines
        let url = try createTempFile(content: "debug line\ninfo line\nerror line\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.levelfilter", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        await reader.loadLogs(for: job)

        // File-based entries default to .info level, so manually test with constructed entries
        // Instead, test the filter logic: default minimumLevel is .debug, so all entries pass
        #expect(reader.minimumLevel == .debug)
        let allCount = reader.filteredEntries.count
        #expect(allCount == 3)

        // Raise minimum to .warning — file-based entries are .info, so none should pass
        reader.minimumLevel = .warning
        #expect(reader.filteredEntries.isEmpty)

        // Reset to .info — all should pass again (file entries are .info)
        reader.minimumLevel = .info
        #expect(reader.filteredEntries.count == 3)
    }

    @Test("LogReader filteredEntries combines text and level filters")
    func filteredEntriesCombined() async throws {
        let url = try createTempFile(content: "hello world\ngoodbye world\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.combined", executablePath: nil, standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        reader.filterText = "hello"
        reader.minimumLevel = .info
        #expect(reader.filteredEntries.count == 1)

        // Raise level above .info — text match doesn't matter
        reader.minimumLevel = .error
        #expect(reader.filteredEntries.isEmpty)
    }

    @Test("LogReader isReading is false after load completes")
    func isReadingFalseAfterLoad() async {
        let job = MockJob(label: "com.test.isreading", executablePath: nil, standardOutPath: nil, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)
        #expect(reader.isReading == false)
    }

    @Test("LogReader refresh with no prior load does not crash")
    func refreshWithoutLoad() async {
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.refresh()
        #expect(reader.isReading == false)
    }

    @Test("LogReader loadLogs resets entries on new job")
    func loadResetsEntries() async throws {
        let url1 = try createTempFile(content: "job1 line\n")
        defer { try? FileManager.default.removeItem(at: url1) }
        let url2 = try createTempFile(content: "job2 line\n")
        defer { try? FileManager.default.removeItem(at: url2) }

        let job1 = MockJob(label: "com.test.job1", executablePath: nil, standardOutPath: url1.path, standardErrorPath: nil)
        let job2 = MockJob(label: "com.test.job2", executablePath: nil, standardOutPath: url2.path, standardErrorPath: nil)

        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job1)
        let firstStdout = reader.entries.filter { $0.source == .stdout }
        #expect(firstStdout.count == 1)
        #expect(firstStdout[0].message == "job1 line")

        await reader.loadLogs(for: job2)
        let secondStdout = reader.entries.filter { $0.source == .stdout }
        #expect(secondStdout.count == 1)
        #expect(secondStdout[0].message == "job2 line")
    }

    @Test("LogReader loadLogs with executable path")
    func loadLogsWithExecutablePath() async throws {
        let url = try createTempFile(content: "with exe path\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let job = MockJob(label: "com.test.exepath", executablePath: "/usr/bin/some_daemon", standardOutPath: url.path, standardErrorPath: nil)
        let reader = LogReader(systemLogReader: NoOpSystemLogReader())
        await reader.loadLogs(for: job)

        let stdoutEntries = reader.entries.filter { $0.source == .stdout }
        #expect(stdoutEntries.count == 1)
    }
}
