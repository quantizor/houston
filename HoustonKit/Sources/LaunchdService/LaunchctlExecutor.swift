import Foundation
import os
import Models
import PrivilegedHelper

private let logger = Logger(subsystem: "com.quantizor.houston", category: "LaunchctlExecutor")

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

// MARK: - Protocol

public protocol LaunchctlExecuting: Sendable {
    func list() async throws -> [LaunchctlListEntry]
    func bootstrap(domain: String, plistPath: String) async throws
    func bootout(domain: String, plistPath: String) async throws
    func enable(serviceTarget: String) async throws
    func disable(serviceTarget: String) async throws
    func kickstart(serviceTarget: String) async throws
    func print(serviceTarget: String) async throws -> String
    func serviceInfo(serviceTarget: String) async -> ServiceInfo
    func processStartTime(pid: Int) async -> Date?
    func killProcess(pid: Int) async throws
}

// MARK: - Direct Process() executor (for development/testing outside sandbox)

public struct LaunchctlExecutor: LaunchctlExecuting {
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

    public func killProcess(pid: Int) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["-9", "\(pid)"]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsing helpers (static, shared with XPCLaunchctlExecutor)

    static func parseInt(from output: String, key: String) -> Int? {
        guard let range = output.range(of: "\(key) = ") else { return nil }
        let rest = output[range.upperBound...]
        let line = rest.prefix(while: { $0 != "\n" && $0 != "\t" })
        return Int(line.trimmingCharacters(in: .whitespaces))
    }

    static func parseString(from output: String, key: String) -> String? {
        guard let range = output.range(of: "\(key) = ") else { return nil }
        let rest = output[range.upperBound...]
        let line = rest.prefix(while: { $0 != "\n" })
        let value = line.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    public static func parseListOutput(_ output: String) -> [LaunchctlListEntry] {
        let lines = output.components(separatedBy: "\n")
        var entries: [LaunchctlListEntry] = []

        for (index, line) in lines.enumerated() {
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

// MARK: - XPC executor (for sandboxed app, delegates to privileged helper)

public struct XPCLaunchctlExecutor: LaunchctlExecuting {
    private let client: PrivilegedHelperClient

    public init(client: PrivilegedHelperClient) {
        self.client = client
    }

    public func list() async throws -> [LaunchctlListEntry] {
        let result = try await client.executeLaunchctl(arguments: ["list"])
        return LaunchctlExecutor.parseListOutput(result.stdout)
    }

    public func bootstrap(domain: String, plistPath: String) async throws {
        _ = try await client.executeLaunchctl(arguments: ["bootstrap", domain, plistPath])
    }

    public func bootout(domain: String, plistPath: String) async throws {
        _ = try await client.executeLaunchctl(arguments: ["bootout", domain, plistPath])
    }

    public func enable(serviceTarget: String) async throws {
        _ = try await client.executeLaunchctl(arguments: ["enable", serviceTarget])
    }

    public func disable(serviceTarget: String) async throws {
        _ = try await client.executeLaunchctl(arguments: ["disable", serviceTarget])
    }

    public func kickstart(serviceTarget: String) async throws {
        _ = try await client.executeLaunchctl(arguments: ["kickstart", "-k", serviceTarget])
    }

    public func print(serviceTarget: String) async throws -> String {
        let result = try await client.executeLaunchctl(arguments: ["print", serviceTarget])
        return result.stdout
    }

    public func serviceInfo(serviceTarget: String) async -> ServiceInfo {
        var info = ServiceInfo()
        guard let result = try? await client.executeLaunchctl(arguments: ["print", serviceTarget]) else {
            return info
        }

        let output = result.stdout
        info.runs = LaunchctlExecutor.parseInt(from: output, key: "runs")
        info.activeCount = LaunchctlExecutor.parseInt(from: output, key: "active count")
        info.forks = LaunchctlExecutor.parseInt(from: output, key: "forks")
        info.execs = LaunchctlExecutor.parseInt(from: output, key: "execs")
        info.lastExitReason = LaunchctlExecutor.parseString(from: output, key: "last exit reason")
        info.spawnType = LaunchctlExecutor.parseString(from: output, key: "spawn type")

        return info
    }

    public func processStartTime(pid: Int) async -> Date? {
        guard let result = try? await client.executeProcess(
            path: "/bin/ps",
            arguments: ["-p", "\(pid)", "-o", "lstart="]
        ) else {
            return nil
        }

        let str = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
        return formatter.date(from: str)
    }

    public func killProcess(pid: Int) async throws {
        _ = try await client.executeProcess(
            path: "/bin/kill",
            arguments: ["-9", "\(pid)"]
        )
    }
}

// MARK: - Fallback executor (tries direct first, falls back to XPC)

/// Attempts each operation via direct Process() first. If that fails (e.g. in a
/// sandboxed app where Process() is blocked), falls back to the XPC helper.
/// Direct-first is correct because launchctl commands like `list` are
/// context-sensitive — running as root via XPC returns different results than
/// running as the current user.
public struct FallbackLaunchctlExecutor: LaunchctlExecuting {
    private let xpc: XPCLaunchctlExecutor
    private let direct: LaunchctlExecutor

    public init(client: PrivilegedHelperClient) {
        self.xpc = XPCLaunchctlExecutor(client: client)
        self.direct = LaunchctlExecutor()
    }

    public func list() async throws -> [LaunchctlListEntry] {
        do {
            let result = try await direct.list()
            logger.info("list: direct succeeded with \(result.count) entries")
            return result
        } catch {
            logger.warning("list: direct failed (\(error)), trying XPC")
            return try await xpc.list()
        }
    }

    public func bootstrap(domain: String, plistPath: String) async throws {
        do { try await direct.bootstrap(domain: domain, plistPath: plistPath) }
        catch { try await xpc.bootstrap(domain: domain, plistPath: plistPath) }
    }

    public func bootout(domain: String, plistPath: String) async throws {
        do { try await direct.bootout(domain: domain, plistPath: plistPath) }
        catch { try await xpc.bootout(domain: domain, plistPath: plistPath) }
    }

    public func enable(serviceTarget: String) async throws {
        do { try await direct.enable(serviceTarget: serviceTarget) }
        catch { try await xpc.enable(serviceTarget: serviceTarget) }
    }

    public func disable(serviceTarget: String) async throws {
        do { try await direct.disable(serviceTarget: serviceTarget) }
        catch { try await xpc.disable(serviceTarget: serviceTarget) }
    }

    public func kickstart(serviceTarget: String) async throws {
        do { try await direct.kickstart(serviceTarget: serviceTarget) }
        catch { try await xpc.kickstart(serviceTarget: serviceTarget) }
    }

    public func print(serviceTarget: String) async throws -> String {
        do { return try await direct.print(serviceTarget: serviceTarget) }
        catch { return try await xpc.print(serviceTarget: serviceTarget) }
    }

    public func serviceInfo(serviceTarget: String) async -> ServiceInfo {
        let info = await direct.serviceInfo(serviceTarget: serviceTarget)
        if info.runs == nil && info.lastExitReason == nil {
            return await xpc.serviceInfo(serviceTarget: serviceTarget)
        }
        return info
    }

    public func processStartTime(pid: Int) async -> Date? {
        if let date = await direct.processStartTime(pid: pid) {
            return date
        }
        return await xpc.processStartTime(pid: pid)
    }

    public func killProcess(pid: Int) async throws {
        do { try await direct.killProcess(pid: pid) }
        catch { try await xpc.killProcess(pid: pid) }
    }
}
