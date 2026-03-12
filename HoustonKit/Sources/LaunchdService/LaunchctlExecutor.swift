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
