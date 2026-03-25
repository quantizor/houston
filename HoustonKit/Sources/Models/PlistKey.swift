public struct PlistKey: Identifiable, Sendable {
    public let id: String
    public let key: String
    public let type: PlistValueType
    public let description: String
    public let required: Bool
    public let category: PlistKeyCategory

    public init(
        key: String,
        type: PlistValueType,
        description: String,
        required: Bool = false,
        category: PlistKeyCategory
    ) {
        self.id = key
        self.key = key
        self.type = type
        self.description = description
        self.required = required
        self.category = category
    }

    public static let allKeys: [PlistKey] = [
        // Identification
        PlistKey(key: "Label", type: .string, description: "Unique identifier for the job", required: true, category: .identification),
        PlistKey(key: "Disabled", type: .boolean, description: "If true, the job is not loaded by default", category: .identification),

        // Execution
        PlistKey(key: "Program", type: .string, description: "Path to the executable", category: .execution),
        PlistKey(key: "ProgramArguments", type: .array, description: "Array of strings: executable path followed by arguments", category: .execution),
        PlistKey(key: "WorkingDirectory", type: .string, description: "Directory to chdir to before running", category: .execution),
        PlistKey(key: "EnvironmentVariables", type: .dictionary, description: "Additional environment variables for the job", category: .execution),
        PlistKey(key: "EnableGlobbing", type: .boolean, description: "Enable shell globbing for ProgramArguments", category: .execution),

        // Scheduling
        PlistKey(key: "RunAtLoad", type: .boolean, description: "Launch the job as soon as it is loaded", category: .scheduling),
        PlistKey(key: "StartInterval", type: .integer, description: "Start the job every N seconds", category: .scheduling),
        PlistKey(key: "StartCalendarInterval", type: .dictionary, description: "Start the job at specific calendar times", category: .scheduling),
        PlistKey(key: "WatchPaths", type: .array, description: "Start the job when any of these paths are modified", category: .scheduling),
        PlistKey(key: "QueueDirectories", type: .array, description: "Start the job when directories become non-empty", category: .scheduling),
        PlistKey(key: "StartOnMount", type: .boolean, description: "Start the job when a filesystem is mounted", category: .scheduling),

        // Lifecycle
        PlistKey(key: "KeepAlive", type: .boolean, description: "Keep the job alive (restart on exit); can also be a dictionary of conditions", category: .lifecycle),
        PlistKey(key: "ThrottleInterval", type: .integer, description: "Minimum interval between job spawns (default 10s)", category: .lifecycle),
        PlistKey(key: "ExitTimeOut", type: .integer, description: "Seconds to wait before sending SIGKILL after SIGTERM", category: .lifecycle),
        PlistKey(key: "AbandonProcessGroup", type: .boolean, description: "Allow child processes to survive job exit", category: .lifecycle),
        PlistKey(key: "LimitLoadToSessionType", type: .string, description: "Restrict loading to a specific session type", category: .lifecycle),
        PlistKey(key: "LimitLoadToHardware", type: .dictionary, description: "Restrict loading to specific hardware", category: .lifecycle),
        PlistKey(key: "LimitLoadFromHardware", type: .dictionary, description: "Prevent loading on specific hardware", category: .lifecycle),

        // Security
        PlistKey(key: "UserName", type: .string, description: "User to run the job as (daemons only)", category: .security),
        PlistKey(key: "GroupName", type: .string, description: "Group to run the job as (daemons only)", category: .security),
        PlistKey(key: "RootDirectory", type: .string, description: "chroot to this directory before running", category: .security),
        PlistKey(key: "Umask", type: .integer, description: "File creation mask for the job", category: .security),
        PlistKey(key: "InitGroups", type: .boolean, description: "Initialize supplementary groups for UserName", category: .security),

        // I/O
        PlistKey(key: "StandardOutPath", type: .string, description: "File to redirect stdout to", category: .io),
        PlistKey(key: "StandardErrorPath", type: .string, description: "File to redirect stderr to", category: .io),
        PlistKey(key: "StandardInPath", type: .string, description: "File to redirect stdin from", category: .io),
        PlistKey(key: "Debug", type: .boolean, description: "Enable extra logging for the job", category: .io),

        // Resources
        PlistKey(key: "SoftResourceLimits", type: .dictionary, description: "Soft resource limits for the job", category: .resources),
        PlistKey(key: "HardResourceLimits", type: .dictionary, description: "Hard resource limits for the job", category: .resources),
        PlistKey(key: "Nice", type: .integer, description: "Scheduling priority adjustment (-20 to 20)", category: .resources),
        PlistKey(key: "ProcessType", type: .string, description: "Process type hint (Background, Standard, Adaptive, Interactive)", category: .resources),
        PlistKey(key: "LowPriorityIO", type: .boolean, description: "Reduce I/O priority", category: .resources),
        PlistKey(key: "LowPriorityBackgroundIO", type: .boolean, description: "Reduce background I/O priority", category: .resources),

        // Networking
        PlistKey(key: "Sockets", type: .dictionary, description: "Sockets to create and pass to the job on launch", category: .networking),
        PlistKey(key: "inetdCompatibility", type: .dictionary, description: "Run the job in inetd-compatible mode", category: .networking),
        PlistKey(key: "MachServices", type: .dictionary, description: "Mach services to register for the job", category: .networking),

        // Deprecated
        PlistKey(key: "OnDemand", type: .boolean, description: "Deprecated: use KeepAlive instead", category: .deprecated),
        PlistKey(key: "ServiceIPC", type: .boolean, description: "Deprecated: use MachServices or Sockets instead", category: .deprecated),

        // Additional keys
        PlistKey(key: "AssociatedBundleIdentifiers", type: .array, description: "Bundle identifiers associated with this job", category: .identification),
        PlistKey(key: "EnablePressuredExit", type: .boolean, description: "Allow the system to terminate the job under memory pressure", category: .lifecycle),
        PlistKey(key: "EnableTransactions", type: .boolean, description: "Enable transaction-based lifecycle management", category: .lifecycle),
        PlistKey(key: "LaunchEvents", type: .dictionary, description: "Event-driven launch triggers", category: .scheduling),
        PlistKey(key: "MaterializeDatalessFiles", type: .boolean, description: "Materialize dataless files before execution", category: .execution),
    ]
}

public enum PlistValueType: String, Sendable {
    case string
    case integer
    case boolean
    case array
    case dictionary
    case date
}

public enum PlistKeyCategory: String, CaseIterable, Sendable {
    case identification
    case execution
    case scheduling
    case lifecycle
    case security
    case io
    case resources
    case networking
    case deprecated
}

extension PlistKey {
    /// Lookup a PlistKey by its key name. Returns nil if not found.
    public static func lookup(_ key: String) -> PlistKey? {
        _keysByName[key]
    }

    /// Cached dictionary for O(1) lookup by key name.
    private static let _keysByName: [String: PlistKey] = {
        Dictionary(uniqueKeysWithValues: allKeys.map { ($0.key, $0) })
    }()
}
