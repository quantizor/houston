import Foundation

// MARK: - Helper Protocol (duplicated here since the helper is a standalone executable)

@objc protocol HelperProtocol {
    func writePlist(_ data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void)
    func deletePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void)
    func executeLaunchctl(arguments: [String], withReply reply: @escaping (Bool, String?, String?) -> Void)
    func getVersion(withReply reply: @escaping (String) -> Void)
}

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
    "bootstrap", "bootout", "enable", "disable", "kickstart",
]

// MARK: - HelperTool

class HelperTool: NSObject, HelperProtocol, NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: HelperProtocol

    func writePlist(_ data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void) {
        guard isPathAllowed(path) else {
            reply(false, "Path is not allowed: \(path)")
            return
        }

        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            // Set standard permissions: owner rw, group/other read
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: path
            )
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func deletePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void) {
        guard isPathAllowed(path) else {
            reply(false, "Path is not allowed: \(path)")
            return
        }

        do {
            try FileManager.default.removeItem(atPath: path)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func executeLaunchctl(arguments: [String], withReply reply: @escaping (Bool, String?, String?) -> Void) {
        guard let subcommand = arguments.first, allowedSubcommands.contains(subcommand) else {
            reply(false, nil, "Disallowed or missing launchctl subcommand. Allowed: \(allowedSubcommands.sorted().joined(separator: ", "))")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            reply(false, nil, "Failed to launch process: \(error.localizedDescription)")
            return
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            reply(true, stdoutStr, stderrStr)
        } else {
            reply(false, stdoutStr, stderrStr)
        }
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}

// MARK: - Entry point

let delegate = HelperTool()
let listener = NSXPCListener(machServiceName: "com.houston.helper")
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
