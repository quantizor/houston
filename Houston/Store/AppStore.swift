import SwiftUI
import os
import Models
import LaunchdService
import JobAnalyzer
import LogViewer
import PlistEditor
import PrivilegedHelper

private let logger = Logger(subsystem: "com.quantizor.houston", category: "AppStore")

@Observable @MainActor
final class AppStore {
    // Services
    let launchdService: LaunchdService
    private let helperClient: PrivilegedHelperClient

    init() {
        let helperClient = PrivilegedHelperClient()
        self.helperClient = helperClient
        let executor = FallbackLaunchctlExecutor(client: helperClient)
        launchdService = LaunchdService(executor: executor, privilegedHelper: helperClient)
        logReader = LogReader(helperClient: helperClient)
    }
    let jobAnalyzer = JobAnalyzer()
    let logReader: LogReader

    /// Ensure the privileged helper is installed (required for sandboxed operation).
    /// In debug builds without sandbox, the helper is unnecessary — direct Process() works.
    func ensureHelperInstalled() async {
        #if !DEBUG
        let available = await helperClient.isHelperAvailable()
        logger.info("Helper available: \(available)")
        guard !available else { return }
        do {
            try await helperClient.installHelper()
            logger.info("Helper installed successfully")
        } catch {
            logger.error("Helper install failed: \(error)")
            showToast(.error, "Failed to install privileged helper: \(error.localizedDescription)")
        }
        #else
        logger.info("Debug build — skipping helper installation (direct Process() available)")
        #endif
    }

    // State
    var selectedDomain: JobDomainType? = nil
    var selectedFilter: JobFilter? = nil
    var selectedJobIDs: Set<String> = []
    var showingDeleteConfirmation: Bool = false
    var searchText: String = ""
    var showingKeyPalette: Bool = false

    // Toast feedback
    var currentToast: Toast? = nil
    private var toastDismissTask: Task<Void, Never>?

    // Editor state
    var editorViewModel = PlistEditorViewModel()

    // Analysis results and runtime info for the currently selected job
    var currentAnalysisResults: [AnalysisResult] = []
    var currentServiceInfo: ServiceInfo?

    enum JobFilter: String, CaseIterable, Identifiable {
        case all = "All Jobs"
        case running = "Running"
        case errors = "Errors"
        case disabled = "Disabled"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .running: return "play.circle"
            case .errors: return "exclamationmark.triangle"
            case .disabled: return "pause.circle"
            }
        }
    }

    // Computed
    var jobs: [LaunchdJob] { launchdService.jobs }
    var isLoading: Bool { launchdService.isLoading }

    var filteredJobs: [LaunchdJob] {
        var result = jobs

        // Filter by domain
        if let domain = selectedDomain {
            result = result.filter { $0.domain == domain }
        }

        // Filter by status
        if let filter = selectedFilter {
            switch filter {
            case .all:
                break
            case .running:
                result = result.filter { $0.status.isRunning }
            case .errors:
                result = result.filter {
                    if case .error = $0.status { return true }
                    return false
                }
            case .disabled:
                result = result.filter { !$0.isEnabled }
            }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var selectedJob: LaunchdJob? {
        guard selectedJobIDs.count == 1, let id = selectedJobIDs.first else { return nil }
        return jobs.first { $0.id == id }
    }

    var selectedJobs: [LaunchdJob] {
        jobs.filter { selectedJobIDs.contains($0.id) }
    }

    // Job counts for sidebar badges
    func jobCount(for domain: JobDomainType) -> Int {
        jobs.filter { $0.domain == domain }.count
    }

    func jobCount(for filter: JobFilter) -> Int {
        switch filter {
        case .all:
            return jobs.count
        case .running:
            return jobs.filter { $0.status.isRunning }.count
        case .errors:
            return jobs.filter {
                if case .error = $0.status { return true }
                return false
            }.count
        case .disabled:
            return jobs.filter { !$0.isEnabled }.count
        }
    }

    // MARK: - Toast

    func showToast(_ style: Toast.Style, _ message: String) {
        toastDismissTask?.cancel()
        currentToast = Toast(style: style, message: message)
        let duration: Duration = style == .error ? .seconds(6) : .seconds(2.5)
        toastDismissTask = Task {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled {
                currentToast = nil
            }
        }
    }

    // MARK: - Actions

    func refreshJobs() async {
        do {
            try await launchdService.loadAllJobs()
            logger.info("Loaded \(self.launchdService.jobs.count) jobs")
        } catch {
            logger.error("Failed to load jobs: \(error)")
            showToast(.error, "Failed to load jobs: \(error.localizedDescription)")
        }

        // Re-select current job to refresh detail panel
        if let job = selectedJob {
            selectJob(job)
        }
    }

    func loadJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.loadJob(job)
            showToast(.success, "\(job.displayName) loaded")
        } catch {
            showToast(.error, "Failed to load job: \(error.localizedDescription)")
        }
    }

    func unloadJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.unloadJob(job)
            showToast(.success, "\(job.displayName) unloaded")
        } catch {
            showToast(.error, "Failed to unload job: \(error.localizedDescription)")
        }
    }

    func enableJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.enableJob(job)
            showToast(.success, "\(job.displayName) enabled")
        } catch {
            showToast(.error, "Failed to enable job: \(error.localizedDescription)")
        }
    }

    func disableJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.disableJob(job)
            showToast(.success, "\(job.displayName) disabled")
        } catch {
            showToast(.error, "Failed to disable job: \(error.localizedDescription)")
        }
    }

    func startJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.startJob(job)
            showToast(.success, "\(job.displayName) started")
        } catch {
            showToast(.error, "Failed to start job: \(error.localizedDescription)")
        }
    }

    func forceKillJob(_ job: LaunchdJob) async {
        guard case .running(let pid) = job.status else { return }
        do {
            try await launchdService.killProcess(pid: pid)
            showToast(.success, "Process \(pid) killed")
        } catch {
            showToast(.error, "Failed to kill process \(pid): \(error.localizedDescription)")
        }
    }

    func deleteJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.deleteJob(job)
            selectedJobIDs.remove(job.id)
            showToast(.success, "\(job.displayName) deleted")
        } catch {
            showToast(.error, "Failed to delete job: \(error.localizedDescription)")
            await refreshJobs()
        }
    }

    func deleteSelectedJobs() async {
        let toDelete = selectedJobs
        let count = toDelete.count
        do {
            try await launchdService.deleteJobs(toDelete)
            for job in toDelete {
                selectedJobIDs.remove(job.id)
            }
            showToast(.success, "\(count) job\(count == 1 ? "" : "s") deleted")
        } catch {
            showToast(.error, "Failed to delete jobs: \(error.localizedDescription)")
            await refreshJobs()
        }
    }

    private var selectJobTask: Task<Void, Never>?

    func selectJob(_ job: LaunchdJob) {
        selectedJobIDs = [job.id]

        // Cancel any in-flight selection load
        selectJobTask?.cancel()
        currentServiceInfo = nil

        selectJobTask = Task {
            // Read file data off main thread
            let plistData = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: job.plistURL)
            }.value

            guard !Task.isCancelled else { return }

            // Parse and load on main (fast — Data is already in memory)
            if let data = plistData,
               let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                editorViewModel.load(job: job, plistContents: dict)
                currentAnalysisResults = jobAnalyzer.analyze(job: job, plistContents: dict)
            }

            guard !Task.isCancelled else { return }

            // Fetch runtime info and logs concurrently
            async let serviceInfo = launchdService.fetchServiceInfo(for: job)
            async let logs: Void = logReader.loadLogs(for: job)

            let info = await serviceInfo
            _ = await logs

            guard !Task.isCancelled else { return }
            currentServiceInfo = info
        }
    }

    func saveCurrentJob() async {
        guard let job = selectedJob else { return }
        do {
            try await launchdService.saveJob(job)
            showToast(.success, "Changes saved")
        } catch {
            showToast(.error, "Failed to save job: \(error.localizedDescription)")
        }
    }
}
