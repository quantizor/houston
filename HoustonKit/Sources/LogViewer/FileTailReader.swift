import Foundation

public actor FileTailReader {
    private let fileURL: URL
    private var lastOffset: UInt64 = 0
    private let source: LogEntry.LogSource

    public init(fileURL: URL, source: LogEntry.LogSource = .stdout) {
        self.fileURL = fileURL
        self.source = source
    }

    public func readAll() throws -> [LogEntry] {
        lastOffset = 0
        return try readFromCurrentOffset()
    }

    public func readNew() throws -> [LogEntry] {
        return try readFromCurrentOffset()
    }

    public func reset() {
        lastOffset = 0
    }

    private func readFromCurrentOffset() throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            return []
        }
        defer { try? handle.close() }

        handle.seek(toFileOffset: lastOffset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else {
            return []
        }

        lastOffset = handle.offsetInFile

        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        return lines
            .filter { !$0.isEmpty }
            .map { line in
                LogEntry(
                    timestamp: Date(),
                    message: line,
                    source: source,
                    level: source == .stderr ? .error : .info
                )
            }
    }
}
