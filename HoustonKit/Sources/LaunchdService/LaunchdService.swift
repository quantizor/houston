import Foundation
import Observation
import os
import Models
import PrivilegedHelper

private let logger = Logger(subsystem: "com.quantizor.houston", category: "LaunchdService")

public enum LaunchdServiceError: LocalizedError {
    case deletionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .deletionFailed(let details): "Failed to delete:\n\(details)"
        }
    }
}

@Observable @MainActor
public final class LaunchdService {
    public private(set) var jobs: [LaunchdJob] = []
    public private(set) var isLoading: Bool = false

    private let executor: any LaunchctlExecuting
    private let parser: PlistParser
    private let writer: PlistWriter
    private let privilegedHelper: PrivilegedHelperClient

    public init(
        executor: any LaunchctlExecuting = LaunchctlExecutor(),
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

        logger.info("loadAllJobs: starting")

        // Kick off status fetch concurrently with discovery
        let executor = self.executor
        let statusTask = Task.detached {
            do {
                let entries = try await executor.list()
                logger.info("loadAllJobs: list returned \(entries.count) entries")
                return entries
            } catch {
                logger.error("loadAllJobs: list failed: \(error)")
                throw error
            }
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

    // MARK: - Service Info

    /// Fetch detailed runtime info for a specific job from launchctl print.
    public func fetchServiceInfo(for job: LaunchdJob) async -> ServiceInfo {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        var info = await executor.serviceInfo(serviceTarget: serviceTarget)

        // Get process start time if running
        if case .running(let pid) = job.status {
            info.processStartTime = await executor.processStartTime(pid: pid)
        }

        return info
    }

    // MARK: - CRUD

    /// Bootstrap (load) a job into launchd.
    public func loadJob(_ job: LaunchdJob) async throws {
        let domain = job.domain.launchctlDomain
        try await executor.bootstrap(domain: domain, plistPath: job.plistURL.path)
        try await refreshStatus()
    }

    /// Bootout (unload) a job from launchd.
    public func unloadJob(_ job: LaunchdJob) async throws {
        let domain = job.domain.launchctlDomain
        try await executor.bootout(domain: domain, plistPath: job.plistURL.path)
        try await refreshStatus()
    }

    /// Enable a job.
    public func enableJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        try await executor.enable(serviceTarget: serviceTarget)
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index].isEnabled = true
        }
    }

    /// Disable a job.
    public func disableJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        try await executor.disable(serviceTarget: serviceTarget)
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index].isEnabled = false
        }
    }

    /// Kickstart (run) a job immediately.
    public func startJob(_ job: LaunchdJob) async throws {
        let serviceTarget = "\(job.domain.launchctlDomain)/\(job.label)"
        try await executor.kickstart(serviceTarget: serviceTarget)
        try await refreshStatus()
    }

    /// Force-kill a running process by PID.
    public func killProcess(pid: Int) async throws {
        try await executor.killProcess(pid: pid)
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
            try await privilegedHelper.writePlist(data, toPath: plistURL.path)
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
            try await privilegedHelper.deletePlist(atPath: job.plistURL.path)
        } else {
            try FileManager.default.removeItem(at: job.plistURL)
        }

        // Remove from local list
        jobs.removeAll { $0.id == job.id }
    }

    /// Delete multiple jobs in a batch.
    public func deleteJobs(_ jobsToDelete: [LaunchdJob]) async throws {
        var deleted: Set<LaunchdJob.ID> = []
        var errors: [String] = []

        for job in jobsToDelete {
            // Unload first (best-effort, don't block deletion)
            if job.status.isLoaded {
                if job.domain.requiresPrivilege {
                    _ = try? await privilegedHelper.executeLaunchctl(arguments: [
                        "bootout", job.domain.launchctlDomain, job.plistURL.path
                    ])
                } else {
                    try? await executor.bootout(domain: job.domain.launchctlDomain, plistPath: job.plistURL.path)
                }
            }

            // Delete plist — propagate errors
            do {
                if job.domain.requiresPrivilege {
                    try await privilegedHelper.deletePlist(atPath: job.plistURL.path)
                } else {
                    try FileManager.default.removeItem(at: job.plistURL)
                }
                deleted.insert(job.id)
            } catch {
                errors.append("\(job.displayName): \(error.localizedDescription)")
            }
        }

        // Only remove jobs whose plist was actually deleted
        jobs.removeAll { deleted.contains($0.id) }
        try await refreshStatus()

        if !errors.isEmpty {
            throw LaunchdServiceError.deletionFailed(errors.joined(separator: "\n"))
        }
    }

    /// Save a job's promoted fields back to its plist file.
    public func saveJob(_ job: LaunchdJob) async throws {
        if job.domain.requiresPrivilege {
            let data = try writer.writeData(job: job)
            try await privilegedHelper.writePlist(data, toPath: job.plistURL.path)
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
