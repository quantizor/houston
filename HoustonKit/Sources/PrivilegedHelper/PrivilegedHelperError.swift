import Foundation

public enum PrivilegedHelperError: LocalizedError, Sendable {
    case notInstalled
    case connectionFailed
    case operationFailed(String)
    case invalidPath(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Privileged helper is not installed. Please install it from Houston preferences."
        case .connectionFailed:
            return "Failed to connect to the privileged helper."
        case .operationFailed(let detail):
            return "Privileged operation failed: \(detail)"
        case .invalidPath(let path):
            return "Path is not allowed: \(path). Only /Library/LaunchAgents and /Library/LaunchDaemons are permitted."
        case .timeout:
            return "Privileged helper operation timed out."
        }
    }
}
