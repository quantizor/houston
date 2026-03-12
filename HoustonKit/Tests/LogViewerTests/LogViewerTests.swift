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

@Suite("LogReader Tests")
@MainActor
struct LogReaderTests {
    @Test("LogReader can be initialized")
    func canInit() {
        let reader = LogReader()
        #expect(reader.entries.isEmpty)
        #expect(reader.isReading == false)
        #expect(reader.filterText.isEmpty)
    }

    @Test("Clear removes all entries")
    func clear() {
        let reader = LogReader()
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

        let reader = LogReader()
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
        let reader = LogReader()
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
    @Test("SystemLogReader can be initialized")
    func canInit() {
        let reader = SystemLogReader()
        #expect(reader != nil)
    }

    @Test("SystemLogReader query handles gracefully")
    func queryGraceful() async {
        let reader = SystemLogReader()
        // Should not crash — returns empty for nonexistent label
        let entries = await reader.query(label: "com.nonexistent.test.label")
        #expect(entries != nil)
    }
}
