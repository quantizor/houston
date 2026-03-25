import Foundation

// MARK: - Path validation

private let allowedDirectories = [
    "/Library/LaunchAgents",
    "/Library/LaunchDaemons",
]

private func isPathAllowed(_ path: String) -> Bool {
    let resolved = (path as NSString).resolvingSymlinksInPath
    let normalised = (resolved as NSString).standardizingPath

    return allowedDirectories.contains { directory in
        let prefix = directory + "/"
        return normalised.hasPrefix(prefix) || normalised == directory
    }
}

// MARK: - Allowed launchctl subcommands

private let allowedSubcommands: Set<String> = [
    "bootstrap", "bootout", "enable", "disable", "kickstart", "list", "print",
]

// MARK: - Allowed executables

private let allowedExecutables: Set<String> = [
    "/bin/ps",
    "/bin/kill",
]

// MARK: - Process execution helper

private struct ProcessOutput {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func runProcess(_ executableURL: URL, arguments: [String], qualityOfService: QualityOfService? = nil) -> ProcessOutput {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    if let qos = qualityOfService {
        process.qualityOfService = qos
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        return ProcessOutput(exitCode: -1, stdout: "", stderr: "Failed to launch process: \(error.localizedDescription)")
    }

    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return ProcessOutput(
        exitCode: process.terminationStatus,
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? ""
    )
}

// MARK: - Request handler

private func handleRequest(_ request: HelperRequest) -> HelperResponse {
    switch request {
    case .writePlist(let data, let path):
        return handleWritePlist(data: data, path: path)
    case .deletePlist(let path):
        return handleDeletePlist(path: path)
    case .executeLaunchctl(let arguments, let uid):
        return handleExecuteLaunchctl(arguments: arguments, uid: uid)
    case .executeProcess(let path, let arguments):
        return handleExecuteProcess(path: path, arguments: arguments)
    case .querySystemLog(let predicate, let sinceInterval, let limit):
        return handleQuerySystemLog(predicate: predicate, sinceInterval: sinceInterval, limit: limit)
    case .getVersion:
        return handleGetVersion()
    }
}

// MARK: - Handlers

private func handleWritePlist(data: Data, path: String) -> HelperResponse {
    guard isPathAllowed(path) else {
        return .error("Path is not allowed: \(path)")
    }

    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: path
        )
        return .success
    } catch {
        return .error(error.localizedDescription)
    }
}

private func handleDeletePlist(path: String) -> HelperResponse {
    guard isPathAllowed(path) else {
        return .error("Path is not allowed: \(path)")
    }

    do {
        try FileManager.default.removeItem(atPath: path)
        return .success
    } catch {
        return .error(error.localizedDescription)
    }
}

private func handleExecuteLaunchctl(arguments: [String], uid: UInt32) -> HelperResponse {
    guard let subcommand = arguments.first, allowedSubcommands.contains(subcommand) else {
        return .error("Disallowed or missing launchctl subcommand. Allowed: \(allowedSubcommands.sorted().joined(separator: ", "))")
    }

    // Validate plist path for bootstrap/bootout
    if (subcommand == "bootstrap" || subcommand == "bootout") && arguments.count >= 3 {
        let plistPath = arguments[2]
        guard isPathAllowed(plistPath) else {
            return .error("Path is not allowed for \(subcommand): \(plistPath)")
        }
    }

    let launchctl = URL(fileURLWithPath: "/bin/launchctl")

    // Run as the requesting user's identity so launchctl sees the correct domain.
    // uid == 0 means run as root (system domain operations).
    let effectiveArgs: [String]
    let qos: QualityOfService?
    if uid != 0 {
        effectiveArgs = ["asuser", "\(uid)", "/bin/launchctl"] + arguments
        qos = .userInitiated
    } else {
        effectiveArgs = arguments
        qos = nil
    }

    let output = runProcess(launchctl, arguments: effectiveArgs, qualityOfService: qos)

    if output.exitCode == 0 {
        return .processOutput(stdout: output.stdout, stderr: output.stderr)
    } else if output.exitCode == -1 {
        return .error(output.stderr)
    } else {
        return .error(output.stderr.isEmpty ? "launchctl exited with status \(output.exitCode)" : output.stderr)
    }
}

private func handleExecuteProcess(path: String, arguments: [String]) -> HelperResponse {
    guard allowedExecutables.contains(path) else {
        return .error("Disallowed executable: \(path). Allowed: \(allowedExecutables.sorted().joined(separator: ", "))")
    }

    // Validate arguments for /bin/kill: only allow signal + numeric PID
    if path == "/bin/kill" {
        let validKillArgs = arguments.allSatisfy { arg in
            arg.hasPrefix("-") || Int(arg) != nil
        }
        guard validKillArgs else {
            return .error("Invalid arguments for /bin/kill")
        }
    }

    let output = runProcess(URL(fileURLWithPath: path), arguments: arguments)

    if output.exitCode == 0 {
        return .processOutput(stdout: output.stdout, stderr: output.stderr)
    } else if output.exitCode == -1 {
        return .error(output.stderr)
    } else {
        return .error(output.stderr.isEmpty ? "Process exited with status \(output.exitCode)" : output.stderr)
    }
}

private func handleQuerySystemLog(predicate: String, sinceInterval: Double, limit: Int) -> HelperResponse {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/log")

    var args = ["show"]
    args += ["--predicate", predicate]

    let seconds = max(1, Int(sinceInterval))
    args += ["--last", "\(seconds)s"]

    args += ["--style", "ndjson"]
    args += ["--info", "--debug"]

    process.arguments = args

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        return .error("Failed to launch log process: \(error.localizedDescription)")
    }

    // Stream output incrementally to avoid buffering huge log results
    let fileHandle = stdoutPipe.fileHandleForReading
    var kept: [String] = []
    var jsonCount = 0
    var buffer = ""

    while true {
        let chunk = fileHandle.readData(ofLength: 64 * 1024)
        if chunk.isEmpty { break }

        buffer += String(data: chunk, encoding: .utf8) ?? ""

        // Process complete lines from buffer
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])

            if limit > 0 {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("{") {
                    jsonCount += 1
                    if jsonCount > limit {
                        process.terminate()
                        return .logOutput(kept.joined(separator: "\n"))
                    }
                }
            }
            kept.append(line)
        }
    }

    // Process any remaining buffer content
    if !buffer.isEmpty {
        kept.append(buffer)
    }

    process.waitUntilExit()
    return .logOutput(kept.joined(separator: "\n"))
}

private func handleGetVersion() -> HelperResponse {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        ?? "unknown"
    return .version(version)
}

// MARK: - Entry point

let listener = try XPCListener(
    service: "com.quantizor.houston.helper",
    targetQueue: nil,
    options: [],
    requirement: .isFromSameTeam(andMatchesSigningIdentifier: nil),
    incomingSessionHandler: { request in
        request.accept(incomingMessageHandler: { (message: HelperRequest) -> HelperResponse? in
            return handleRequest(message)
        }, cancellationHandler: nil)
    }
)

dispatchMain()
