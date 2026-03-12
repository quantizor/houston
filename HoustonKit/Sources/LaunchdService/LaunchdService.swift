import Foundation
import Observation
import Models
import PrivilegedHelper

@Observable @MainActor
public final class LaunchdService {
    public private(set) var jobs: [LaunchdJob] = []
    public private(set) var isLoading: Bool = false

    private let executor: LaunchctlExecutor
    private let parser: PlistParser
    private let writer: PlistWriter
    private let privilegedHelper: PrivilegedHelperClient

    public init(
        executor: LaunchctlExecutor = LaunchctlExecutor(),
        parser: PlistParser = PlistParser(),
        writer: PlistWriter = PlistWriter(),
        privilegedHelper: PrivilegedHelperClient = PrivilegedHelperClient()
    ) {
        self.executor = executor
        self.parser = parser
        self.writer = writer
        self.privilegedHelper = privilegedHelper
    }

    // MARK: - Loading

    /// Scan all domains, discover plists, parse, merge with launchctl status.
    /// Streams results incrementally so the UI stays responsive.
    public func loadAllJobs() async throws {
        isLoading = true
        defer { isLoading = false }

        // Kick off status fetch concurrently with discovery
        let statusTask = Task.detached { [executor] in
            try await executor.list()
        }

        // Discover all plist URLs off the main thread
        let parser = self.parser
        let urlsByDomain = await Task.detached {
            var result: [(URL, JobDomainType)] = []
            for domain in JobDomainType.allCases {
                if let urls = try? parser.discoverPlists(in: domain) {
                    result.append(contentsOf: urls.map { ($0, domain) })
                }
            }
            return result
        }.value

        // Parse in batches, yielding to the main actor between each batch
        // so the UI can process events
        let batchSize = 20
        var allJobs: [LaunchdJob] = []
        allJobs.reserveCapacity(urlsByDomain.count)

        for batchStart in stride(from: 0, to: urlsByDomain.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, urlsByDomain.count)
            let batch = urlsByDomain[batchStart..<batchEnd]

            let parsed = await Task.detached {
                batch.compactMap { (url, domain) in
                    try? parser.parse(url: url, domain: domain)
                }
            }.value

            allJobs.append(contentsOf: parsed)

            // Publish partial results so the list populates progressively
            jobs = allJobs
            await Task.yield()
        }

        // Merge runtime status
        if let listEntries = try? await statusTask.value {
            let entryByLabel = Dictionary(
                listEntries.map { ($0.label, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for index in allJobs.indices {
                let label = allJobs[index].label
                if let entry = entryByLabel[label] {
                    if let pid = entry.pid {
                        allJobs[index].status = .running(pid: pid)
                    } else {
                        allJobs[index].status = .loaded(lastExitCode: entry.lastExitStatus)
                    }
                } else {
                    allJobs[index].status = .unloaded
                }
            }
        }

        jobs = allJobs
    }

    /// Refresh status for all loaded jobs.
    public func refreshStatus() async throws {
        let listEntries = try await executor.list()
        let entryByLabel = Dictionary(listEntries.map { ($0.label, $0) }, uniquingKeysWith: { first, _ in first })

        for index in jobs.indices {
            let label = jobs[index].label
            if let entry = entryByLabel[label] {
                if let pid = entry.pid {
                    jobs[index].status = .running(pid: pid)
                } else {
                    jobs[index].status = .loaded(lastExitCode: entry.lastExitStatus)
                }
            } else {
                jobs[index].status = .unloaded
            }
        }
    }

    // MARK: - Privilege escalation

    /// Run a launchctl command, using the privileged helper if available, falling back to authorized shell.
    private func runPrivilegedLaunchctl(_ arguments: [String]) async throws {
        if await privilegedHelper.isHelperAvailable() {
            _ = try await privilegedHelper.executeLaunchctl(arguments: arguments)
        } else {
            let shellCmd = shellEscape(["/bin/launchctl"] + arguments)
            try await runPrivilegedShellCommands([shellCmd])
        }
    }

    /// Shell-escape an array of arguments into a single command string.
    private nonisolated func shellEscape(_ arguments: [String]) -> String {
        arguments
            .map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            .joined(separator: " ")
    }

    /// Run one or more shell commands with a single admin authentication prompt.
    /// Uses Security.framework AuthorizationServices which supports Touch ID on macOS Sonoma+.
    @discardableResult
    private nonisolated func runPrivilegedShellCommands(_ commands: [String]) async throws -> String {
        // Combine all commands into a single shell invocation
        let combined = commands.joined(separator: " ; ")

        // Use osascript with `with administrator privileges` — on macOS 14+ Apple Silicon,
        // the system auth dialog supports Touch ID when biometrics are enrolled.
        let script = "do shell script \"\(combined)\" with administrator privileges"

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { _ in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    var errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    // Strip osascript noise like "0:150: execution error: "
                    if let range = errStr.range(of: "execution error: ") {
                        errStr = String(errStr[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    // Strip trailing error number like " (5)"
                    if let parenRange = errStr.range(of: #" \(\-?\d+\)$"#, options: .regularExpression) {
                        errStr = String(errStr[..<parenRange.lowerBound])
                    }
                    continuation.resume(throwing: LaunchctlError.commandFailed(
                        exitCode: process.terminationStatus, stderr: errStr
                    ))
                } else {
                    continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Write data to a privileged path, helper-first with authorized shell fallback.
    private func writePrivileged(_ data: Data, toPath path: String) async throws {
        if await privilegedHelper.isHelperAvailable() {
            try await privilegedHelper.writePlist(data, toPath: path)
        } else {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".plist")
            try data.write(to: tempURL)
            let cmd = "cp \(shellEscape([tempURL.path])) \(shellEscape([path]))"
            try await runPrivilegedShellCommands([cmd])
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    /// Delete a file at a privileged path, helper-first with authorized shell fallback.
    private func deletePrivileged(atPath path: String) async throws {
        if await privilegedHelper.isHelperAvailable() {
            try await privilegedHelper.deletePlist(atPath: path)
        } else {
            let cmd = "rm \(shellEscape([path]))"
            try await runPrivilegedShellCommands([cmd])
        }
    }

    // MARK: - CRUD

    /// Bootstrap (load) a job into launchd.
    public func loadJob(_ job: LaunchdJob) async throws {
        let domain = job.domain.launchctlDomain
        if job.domain.requiresPrivilege {
            try await runPrivilegedLaunchctl(["bootstrap", domain, job.plistURL.path])
        } else {
            try await executor.bootstrap(domain: domain, plistPath: job.plistURL.path)
        }
        try await refreshStatus()
    }

    /// Bootout (unload) a job from launchd.
    public func unloadJob(_ job: LaunchdJob) async throws {
        let domain = job.domain.launchctlDomain
        if job.domain.requiresPrivilege {
            try await runPrivilegedLaunchctl(["bootout", domain, job.plistURL.path])
        } else {
            try await executor.bootout(domain: domain, plistPath: job.plistURL.path)
        }
        try await refreshStatus()
    }

    /// Enable a job.
    public func enableJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        if job.domain.requiresPrivilege {
            try await runPrivilegedLaunchctl(["enable", serviceTarget])
        } else {
            try await executor.enable(serviceTarget: serviceTarget)
        }
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index].isEnabled = true
        }
    }

    /// Disable a job.
    public func disableJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        if job.domain.requiresPrivilege {
            try await runPrivilegedLaunchctl(["disable", serviceTarget])
        } else {
            try await executor.disable(serviceTarget: serviceTarget)
        }
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index].isEnabled = false
        }
    }

    /// Kickstart (run) a job immediately.
    public func startJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        if job.domain.requiresPrivilege {
            try await runPrivilegedLaunchctl(["kickstart", "-k", serviceTarget])
        } else {
            try await executor.kickstart(serviceTarget: serviceTarget)
        }
        try await refreshStatus()
    }

    /// Create a new job plist and return the parsed job.
    public func createJob(
        label: String,
        domain: JobDomainType,
        programArguments: [String]
    ) async throws -> LaunchdJob {
        let filename = "\(label).plist"
        let directoryURL = URL(fileURLWithPath: domain.directory, isDirectory: true)
        let plistURL = directoryURL.appendingPathComponent(filename)

        if domain.requiresPrivilege {
            let data = try writer.createNewData(label: label, programArguments: programArguments)
            try await writePrivileged(data, toPath: plistURL.path)
        } else {
            try writer.createNew(label: label, programArguments: programArguments, at: plistURL)
        }

        let job = try parser.parse(url: plistURL, domain: domain)
        jobs.append(job)
        return job
    }

    /// Delete a job: bootout if loaded, then remove the plist file.
    public func deleteJob(_ job: LaunchdJob) async throws {
        // Unload first if loaded
        if job.status.isLoaded {
            try? await unloadJob(job)
        }

        if job.domain.requiresPrivilege {
            try await deletePrivileged(atPath: job.plistURL.path)
        } else {
            try FileManager.default.removeItem(at: job.plistURL)
        }

        // Remove from local list
        jobs.removeAll { $0.id == job.id }
    }

    /// Delete multiple jobs in a batch, prompting for authentication only once.
    public func deleteJobs(_ jobsToDelete: [LaunchdJob]) async throws {
        // Separate into privileged vs user-domain jobs
        let privilegedJobs = jobsToDelete.filter { $0.domain.requiresPrivilege }
        let userJobs = jobsToDelete.filter { !$0.domain.requiresPrivilege }

        // Handle user-domain jobs without privilege escalation
        for job in userJobs {
            if job.status.isLoaded {
                try? await executor.bootout(domain: job.domain.launchctlDomain, plistPath: job.plistURL.path)
            }
            try? FileManager.default.removeItem(at: job.plistURL)
        }

        // Batch privileged operations into a single auth prompt
        if !privilegedJobs.isEmpty {
            if await privilegedHelper.isHelperAvailable() {
                // XPC helper: already authenticated, run sequentially
                for job in privilegedJobs {
                    if job.status.isLoaded {
                        _ = try? await privilegedHelper.executeLaunchctl(arguments: [
                            "bootout", job.domain.launchctlDomain, job.plistURL.path
                        ])
                    }
                    try? await privilegedHelper.deletePlist(atPath: job.plistURL.path)
                }
            } else {
                // Collect all shell commands, execute with single auth prompt
                var commands: [String] = []
                for job in privilegedJobs {
                    if job.status.isLoaded {
                        commands.append(shellEscape([
                            "/bin/launchctl", "bootout", job.domain.launchctlDomain, job.plistURL.path
                        ]))
                    }
                    commands.append("rm \(shellEscape([job.plistURL.path]))")
                }
                try await runPrivilegedShellCommands(commands)
            }
        }

        // Remove from local list
        let deletedIDs = Set(jobsToDelete.map(\.id))
        jobs.removeAll { deletedIDs.contains($0.id) }
        try await refreshStatus()
    }

    /// Save a job's promoted fields back to its plist file.
    public func saveJob(_ job: LaunchdJob) async throws {
        if job.domain.requiresPrivilege {
            let data = try writer.writeData(job: job)
            try await writePrivileged(data, toPath: job.plistURL.path)
        } else {
            try writer.write(job: job, to: job.plistURL)
        }
    }

    /// Update a job's in-memory state and save to disk.
    public func updateAndSaveJob(_ job: LaunchdJob) async throws {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        }
        try await saveJob(job)
    }
}
