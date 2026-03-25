import Foundation

public enum JobDomainType: String, CaseIterable, Identifiable, Sendable {
    case userAgent
    case globalAgent
    case globalDaemon
    case systemAgent
    case systemDaemon
    case launchAngel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userAgent: return "User Agents"
        case .globalAgent: return "Global Agents"
        case .globalDaemon: return "Global Daemons"
        case .systemAgent: return "System Agents"
        case .systemDaemon: return "System Daemons"
        case .launchAngel: return "Launch Angels"
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
        case .systemAgent:
            return "/System/Library/LaunchAgents"
        case .systemDaemon:
            return "/System/Library/LaunchDaemons"
        case .launchAngel:
            return "/System/Library/LaunchAngels"
        }
    }

    public var requiresPrivilege: Bool {
        switch self {
        case .userAgent: return false
        case .globalAgent, .globalDaemon, .systemAgent, .systemDaemon, .launchAngel: return true
        }
    }

    public var launchctlDomain: String {
        switch self {
        case .userAgent, .systemAgent:
            // Both user agents and system agents run in the user's GUI session
            return "gui/\(getuid())"
        case .globalAgent:
            // Global agents from /Library/LaunchAgents also run in the GUI session
            return "gui/\(getuid())"
        case .globalDaemon, .systemDaemon, .launchAngel:
            return "system"
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .systemAgent, .systemDaemon, .launchAngel: return true
        default: return false
        }
    }
}
