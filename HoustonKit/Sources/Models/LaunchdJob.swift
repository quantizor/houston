import Foundation

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
        if let lastComponent = label.split(separator: ".").last {
            return String(lastComponent)
        }
        return label
    }

    /// The vendor prefix, e.g. "com.apple" from "com.apple.Spotlight".
    public var vendor: String {
        let components = label.split(separator: ".")
        if components.count > 2 {
            return components.prefix(2).joined(separator: ".")
        }
        return label
    }
}
