import Foundation
import Models

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct LaunchctlListEntry: Sendable, Equatable {
    public let pid: Int?
    public let lastExitStatus: Int
    public let label: String

    public init(pid: Int?, lastExitStatus: Int, label: String) {
        self.pid = pid
        self.lastExitStatus = lastExitStatus
        self.label = label
    }
}

public struct LaunchctlExecutor: Sendable {
    private let launchctlPath = "/bin/launchctl"

    public init() {}

    // MARK: - Low-level execution

    public func run(_ arguments: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchctlPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: stdoutStr,
                    stderr: stderrStr
                ))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - High-level operations

    public func list() async throws -> [LaunchctlListEntry] {
        let result = try await run(["list"])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        return Self.parseListOutput(result.stdout)
    }

    public func bootstrap(domain: String, plistPath: String) async throws {
        let result = try await run(["bootstrap", domain, plistPath])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    public func bootout(domain: String, plistPath: String) async throws {
        let result = try await run(["bootout", domain, plistPath])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    public func enable(serviceTarget: String) async throws {
        let result = try await run(["enable", serviceTarget])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    public func disable(serviceTarget: String) async throws {
        let result = try await run(["disable", serviceTarget])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    public func kickstart(serviceTarget: String) async throws {
        let result = try await run(["kickstart", "-k", serviceTarget])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    public func print(serviceTarget: String) async throws -> String {
        let result = try await run(["print", serviceTarget])
        if result.exitCode != 0 {
            throw LaunchctlError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        return result.stdout
    }

    /// Fetch runtime info for a specific service via `launchctl print`.
    public func serviceInfo(serviceTarget: String) async -> ServiceInfo {
        var info = ServiceInfo()
        guard let result = try? await run(["print", serviceTarget]),
              result.exitCode == 0 else {
            return info
        }

        let output = result.stdout
        info.runs = Self.parseInt(from: output, key: "runs")
        info.activeCount = Self.parseInt(from: output, key: "active count")
        info.forks = Self.parseInt(from: output, key: "forks")
        info.execs = Self.parseInt(from: output, key: "execs")
        info.lastExitReason = Self.parseString(from: output, key: "last exit reason")
        info.spawnType = Self.parseString(from: output, key: "spawn type")

        return info
    }

    /// Fetch process start time via `ps` for a running PID.
    public func processStartTime(pid: Int) async -> Date? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "lstart="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            return try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !str.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
                    continuation.resume(returning: formatter.date(from: str))
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(returning: nil)
                }
            }
        } catch {
            return nil
        }
    }

    private static func parseInt(from output: String, key: String) -> Int? {
        guard let range = output.range(of: "\(key) = ") else { return nil }
        let rest = output[range.upperBound...]
        let line = rest.prefix(while: { $0 != "\n" && $0 != "\t" })
        return Int(line.trimmingCharacters(in: .whitespaces))
    }

    private static func parseString(from output: String, key: String) -> String? {
        guard let range = output.range(of: "\(key) = ") else { return nil }
        let rest = output[range.upperBound...]
        let line = rest.prefix(while: { $0 != "\n" })
        let value = line.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    // MARK: - Parsing

    public static func parseListOutput(_ output: String) -> [LaunchctlListEntry] {
        let lines = output.components(separatedBy: "\n")
        var entries: [LaunchctlListEntry] = []

        for (index, line) in lines.enumerated() {
            // Skip header line and empty lines
            if index == 0 || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else { continue }

            let pidStr = columns[0].trimmingCharacters(in: .whitespaces)
            let statusStr = columns[1].trimmingCharacters(in: .whitespaces)
            let label = columns[2].trimmingCharacters(in: .whitespaces)

            guard !label.isEmpty else { continue }

            let pid: Int? = pidStr == "-" ? nil : Int(pidStr)
            let lastExitStatus = Int(statusStr) ?? 0

            entries.append(LaunchctlListEntry(
                pid: pid,
                lastExitStatus: lastExitStatus,
                label: label
            ))
        }

        return entries
    }
}
