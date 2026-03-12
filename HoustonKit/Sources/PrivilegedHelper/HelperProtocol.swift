import Foundation

/// XPC protocol for the privileged helper tool.
/// Must be @objc because NSXPCInterface requires Objective-C protocols.
@objc public protocol HelperProtocol {
    /// Write plist data to a path in /Library/LaunchAgents or /Library/LaunchDaemons.
    func writePlist(_ data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void)

    /// Delete a plist at a path in /Library/LaunchAgents or /Library/LaunchDaemons.
    func deletePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void)

    /// Execute a launchctl command with arguments (for bootstrap/bootout of system domain).
    func executeLaunchctl(arguments: [String], withReply reply: @escaping (Bool, String?, String?) -> Void)

    /// Get the helper tool version.
    func getVersion(withReply reply: @escaping (String) -> Void)
}
