public enum JobStatus: Sendable, Equatable {
    case running(pid: Int)
    case loaded(lastExitCode: Int?)
    case unloaded
    case error(String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isLoaded: Bool {
        switch self {
        case .running, .loaded: return true
        case .unloaded, .error: return false
        }
    }

    public var statusDescription: String {
        switch self {
        case .running(let pid):
            return "Running (PID \(pid))"
        case .loaded(let exitCode):
            if let code = exitCode {
                return "Loaded (exit code \(code))"
            }
            return "Loaded"
        case .unloaded:
            return "Not Loaded"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    /// Sort priority: running first, then errors, loaded, unloaded last
    public var sortPriority: Int {
        switch self {
        case .running: return 0
        case .error: return 1
        case .loaded: return 2
        case .unloaded: return 3
        }
    }

    public var statusColor: String {
        switch self {
        case .running: return "green"
        case .loaded: return "yellow"
        case .unloaded: return "gray"
        case .error: return "red"
        }
    }
}
