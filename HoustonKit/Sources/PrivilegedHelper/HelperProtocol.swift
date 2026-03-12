import Foundation

/// XPC protocol for the privileged helper tool.
/// Must be @objc because NSXPCInterface requires Objective-C protocols.
@objc public protocol HelperProtocol {
    /// Write plist data to a path in /Library/LaunchAgents or /Library/LaunchDaemons.
    func writePlist(_ data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void)

    /// Delete a plist at a path in /Library/LaunchAgents or /Library/LaunchDaemons.
    func deletePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void)

    /// Execute a launchctl command with arguments.
    /// Pass asUser UID to run in that user's context (0 = run as root).
    func executeLaunchctl(arguments: [String], asUser uid: UInt32, withReply reply: @escaping (Bool, String?, String?) -> Void)

    /// Execute a whitelisted process (e.g. /bin/ps, /bin/kill) with arguments.
    func executeProcess(path: String, arguments: [String], withReply reply: @escaping (Bool, String?, String?) -> Void)

    /// Query system logs via `log show` for a given predicate and time range.
    /// Returns JSON-formatted log entries.
    func querySystemLog(predicate: String, sinceInterval: Double, limit: Int, withReply reply: @escaping (Bool, String?, String?) -> Void)

    /// Get the helper tool version.
    func getVersion(withReply reply: @escaping (String) -> Void)
}
