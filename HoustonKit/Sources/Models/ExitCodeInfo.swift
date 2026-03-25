import Foundation

/// Human-readable explanations for common Unix/launchd exit codes.
public struct ExitCodeInfo: Sendable {

    /// Explain a numeric exit code.
    public static func explanation(for code: Int) -> String? {
        // Signal-based exits: 128 + signal number
        if code > 128, let signal = signalNames[code - 128] {
            return "Killed by \(signal)"
        }

        return knownCodes[code]
    }

    // sysexits.h (64-78) + common launchd/Unix codes
    private static let knownCodes: [Int: String] = [
        0:   "Exited normally",
        1:   "General error",
        2:   "Misuse of shell command or invalid arguments",
        3:   "Aborted (SIGABRT)",
        6:   "Aborted",
        9:   "Killed (SIGKILL)",
        13:  "Permission denied (SIGPIPE or access error)",
        15:  "Terminated (SIGTERM)",
        64:  "Command line usage error",
        65:  "Data format error",
        66:  "Cannot open input",
        67:  "Unknown user",
        68:  "Unknown host",
        69:  "Service unavailable",
        70:  "Internal software error",
        71:  "System error (OS-level failure)",
        72:  "Critical OS file missing",
        73:  "Can't create output file",
        74:  "Input/output error",
        75:  "Temporary failure — retry may succeed",
        76:  "Remote error in protocol",
        77:  "Permission denied",
        78:  "Configuration error",
        126: "Command found but not executable",
        127: "Command not found",
    ]

    private static let signalNames: [Int: String] = [
        1:  "SIGHUP (hangup)",
        2:  "SIGINT (interrupt)",
        3:  "SIGQUIT (quit)",
        4:  "SIGILL (illegal instruction)",
        6:  "SIGABRT (abort)",
        8:  "SIGFPE (floating point exception)",
        9:  "SIGKILL (force kill)",
        11: "SIGSEGV (segmentation fault)",
        13: "SIGPIPE (broken pipe)",
        14: "SIGALRM (alarm)",
        15: "SIGTERM (terminated)",
    ]
}

/// Synthesizes a plain-English diagnosis from job state, service info, and analysis results.
public struct JobDiagnostic: Sendable {

    public static func diagnose(
        job: LaunchdJob,
        serviceInfo: ServiceInfo?,
        analysisResults: [AnalysisResult],
        plistContents: [String: Any]? = nil
    ) -> String? {
        // Running jobs — report health
        if case .running = job.status {
            let errorCount = analysisResults.filter { $0.severity == .error }.count
            if errorCount > 0 {
                return "Running, but \(errorCount) configuration \(errorCount == 1 ? "issue" : "issues") detected."
            }
            return nil // healthy, no diagnosis needed
        }

        // Disabled jobs
        if !job.isEnabled {
            return "This job is disabled and won't be started by launchd. Enable it to allow execution."
        }

        // Jobs with critical analysis errors
        let criticalErrors = analysisResults.filter { $0.severity == .error }
        if let first = criticalErrors.first {
            if first.title.contains("Missing") && first.title.contains("executable") {
                return "The executable could not be found. Verify the path in Program or ProgramArguments."
            }
            if first.title.contains("Missing Label") {
                return "This plist is missing a Label key — launchd requires it to identify the job."
            }
            return first.title
        }

        // Loaded with non-zero exit
        if case .loaded(let exitCode) = job.status, let code = exitCode, code != 0 {
            let explanation = ExitCodeInfo.explanation(for: code) ?? "Unknown error"
            return "Exited with code \(code): \(explanation). Check logs for details."
        }

        // Unloaded jobs — explain why and what to do
        if case .unloaded = job.status {
            let hasRunAtLoad = job.runAtLoad == true
            let hasInterval = job.startInterval != nil
            let hasCalendar = job.startCalendarInterval != nil
            let hasTrigger = hasRunAtLoad || hasInterval || hasCalendar

            if !hasTrigger {
                return "This job is not loaded and has no automatic trigger (RunAtLoad, StartInterval, or StartCalendarInterval). It must be loaded manually."
            }

            if let scheduleDesc = ScheduleInfo.description(startInterval: job.startInterval, startCalendarInterval: job.startCalendarInterval) {
                return "Not loaded. Schedule: \(scheduleDesc). Load it to activate."
            }
            return "This job is not loaded. Load it to activate, or verify it's registered with launchd."
        }

        // Loaded, exit 0, no errors — show schedule info
        if case .loaded(let exitCode) = job.status {
            if exitCode == nil || exitCode == 0 {
                let hasInterval = job.startInterval != nil
                let hasCalendar = job.startCalendarInterval != nil
                if hasInterval || hasCalendar {
                    let scheduleDesc = ScheduleInfo.description(startInterval: job.startInterval, startCalendarInterval: job.startCalendarInterval) ?? "on schedule"
                    if let nextRun = ScheduleInfo.nextRunString(startInterval: job.startInterval, startCalendarInterval: job.startCalendarInterval) {
                        return "Waiting — \(scheduleDesc), \(nextRun)."
                    }
                    return "Waiting — \(scheduleDesc)."
                }
                return nil // Healthy, no diagnosis needed
            }
        }

        return nil
    }
}
