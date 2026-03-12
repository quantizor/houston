import Foundation

public enum JobDomainType: String, CaseIterable, Identifiable, Sendable {
    case userAgent
    case globalAgent
    case globalDaemon

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userAgent: return "User Agents"
        case .globalAgent: return "Global Agents"
        case .globalDaemon: return "Global Daemons"
        }
    }

    public var directory: String {
        switch self {
        case .userAgent:
            return NSHomeDirectory() + "/Library/LaunchAgents"
        case .globalAgent:
            return "/Library/LaunchAgents"
        case .globalDaemon:
            return "/Library/LaunchDaemons"
        }
    }

    public var requiresPrivilege: Bool {
        switch self {
        case .userAgent: return false
        case .globalAgent, .globalDaemon: return true
        }
    }

    public var launchctlDomain: String {
        switch self {
        case .userAgent:
            return "gui/\(getuid())"
        case .globalAgent, .globalDaemon:
            return "system"
        }
    }
}
