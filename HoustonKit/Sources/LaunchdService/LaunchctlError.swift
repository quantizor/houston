import Foundation

public enum LaunchctlError: Error, Sendable, LocalizedError {
    case commandFailed(exitCode: Int32, stderr: String)
    case parsingFailed(String)
    case invalidLabel(String)
    case plistNotFound(URL)
    case plistReadFailed(URL, String)
    case plistWriteFailed(URL, String)
    case domainDirectoryNotFound(String)
    case jobNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let exitCode, let stderr):
            return "launchctl failed (exit \(exitCode)): \(stderr)"
        case .parsingFailed(let detail):
            return "Failed to parse launchctl output: \(detail)"
        case .invalidLabel(let detail):
            return "Invalid label: \(detail)"
        case .plistNotFound(let url):
            return "Plist file not found: \(url.path)"
        case .plistReadFailed(let url, let detail):
            return "Failed to read plist at \(url.path): \(detail)"
        case .plistWriteFailed(let url, let detail):
            return "Failed to write plist at \(url.path): \(detail)"
        case .domainDirectoryNotFound(let path):
            return "Domain directory not found: \(path)"
        case .jobNotFound(let label):
            return "Job not found: \(label)"
        }
    }
}
