import Foundation

/// Runtime information from `launchctl print`, not available from plist alone.
public struct ServiceInfo: Sendable, Equatable {
    public var runs: Int?
    public var lastExitReason: String?
    public var spawnType: String?
    public var activeCount: Int?
    public var forks: Int?
    public var execs: Int?
    public var processStartTime: Date?

    public init() {}
}

public struct LaunchdJob: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var domain: JobDomainType
    public var plistURL: URL
    public var status: JobStatus
    public var isEnabled: Bool

    // Promoted keys (type-safe access to common plist fields)
    public var programArguments: [String]?
    public var program: String?
    public var runAtLoad: Bool?
    public var keepAlive: Bool?
    public var startInterval: Int?
    public var startCalendarInterval: [String: Int]?
    public var standardOutPath: String?
    public var standardErrorPath: String?
    public var workingDirectory: String?
    public var environmentVariables: [String: String]?
    public var userName: String?
    public var groupName: String?
    public var disabled: Bool?
    public var processType: String?

    public init(
        label: String,
        domain: JobDomainType,
        plistURL: URL,
        status: JobStatus = .unloaded,
        isEnabled: Bool = true
    ) {
        self.id = label
        self.label = label
        self.domain = domain
        self.plistURL = plistURL
        self.status = status
        self.isEnabled = isEnabled
    }

    // Computed
    public var executablePath: String? {
        program ?? programArguments?.first
    }

    public var displayName: String {
        let components = label.split(separator: ".")
        guard components.count >= 2 else { return label }

        let last = String(components.last!)
        let genericSuffixes: Set<String> = ["agent", "daemon", "xpc", "helper", "server", "service", "plist"]
        if genericSuffixes.contains(last.lowercased()), components.count >= 3 {
            // e.g. com.apple.security.agent → "security"
            // com.apple.distnoted.xpc.agent → "distnoted"
            // Find the last meaningful component (skip trailing generic suffixes)
            for i in stride(from: components.count - 1, through: 0, by: -1) {
                let c = String(components[i])
                if !genericSuffixes.contains(c.lowercased()) {
                    return c
                }
            }
        }
        return last
    }

    public var isReadOnly: Bool { domain.isReadOnly }

    /// The vendor prefix, e.g. "com.apple" from "com.apple.Spotlight".
    public var vendor: String {
        let components = label.split(separator: ".")
        if components.count > 2 {
            return components.prefix(2).joined(separator: ".")
        }
        return label
    }
}
