import Foundation

/// Security validation for paths passed to the privileged helper.
/// Only allows operations on files within /Library/LaunchAgents and /Library/LaunchDaemons.
public struct PathValidator: Sendable {
    public static let allowedDirectories: [String] = [
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
    ]

    /// Check whether a path is within an allowed directory.
    /// Resolves symlinks and normalises the path to prevent traversal attacks.
    public static func isAllowed(_ path: String) -> Bool {
        // Resolve symlinks and normalize
        let resolved = (path as NSString).resolvingSymlinksInPath
        let normalised = (resolved as NSString).standardizingPath

        return allowedDirectories.contains { directory in
            // The path must start with the directory followed by a '/' (i.e. be a file inside it)
            let prefix = directory + "/"
            return normalised.hasPrefix(prefix) || normalised == directory
        }
    }

    /// Validate a path and throw if it is not allowed.
    public static func validate(_ path: String) throws {
        guard isAllowed(path) else {
            throw PrivilegedHelperError.invalidPath(path)
        }
    }
}
