import SwiftUI
import Models
import LaunchdService
import JobAnalyzer
import LogViewer
import PlistEditor

@Observable @MainActor
final class AppStore {
    // Services
    let launchdService = LaunchdService()
    let jobAnalyzer = JobAnalyzer()
    let logReader = LogReader()

    // State
    var selectedDomain: JobDomainType? = nil
    var selectedFilter: JobFilter? = nil
    var selectedJobIDs: Set<String> = []
    var showingDeleteConfirmation: Bool = false
    var searchText: String = ""
    var errorMessage: String? = nil
    var showingKeyPalette: Bool = false

    // Editor state
    var editorViewModel = PlistEditorViewModel()

    // Analysis results for the currently selected job
    var currentAnalysisResults: [AnalysisResult] = []

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

    // MARK: - Actions

    func refreshJobs() async {
        do {
            try await launchdService.loadAllJobs()
        } catch {
            errorMessage = "Failed to load jobs: \(error.localizedDescription)"
        }
    }

    func loadJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.loadJob(job)
        } catch {
            errorMessage = "Failed to load job: \(error.localizedDescription)"
        }
    }

    func unloadJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.unloadJob(job)
        } catch {
            errorMessage = "Failed to unload job: \(error.localizedDescription)"
        }
    }

    func enableJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.enableJob(job)
        } catch {
            errorMessage = "Failed to enable job: \(error.localizedDescription)"
        }
    }

    func disableJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.disableJob(job)
        } catch {
            errorMessage = "Failed to disable job: \(error.localizedDescription)"
        }
    }

    func startJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.startJob(job)
        } catch {
            errorMessage = "Failed to start job: \(error.localizedDescription)"
        }
    }

    func forceKillJob(_ job: LaunchdJob) async {
        guard case .running(let pid) = job.status else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["-9", "\(pid)"]
        do {
            try process.run()
            process.waitUntilExit()
            try await launchdService.refreshStatus()
        } catch {
            errorMessage = "Failed to kill process \(pid): \(error.localizedDescription)"
        }
    }

    func deleteJob(_ job: LaunchdJob) async {
        do {
            try await launchdService.deleteJob(job)
            selectedJobIDs.remove(job.id)
        } catch {
            errorMessage = "Failed to delete job: \(error.localizedDescription)"
        }
    }

    func deleteSelectedJobs() async {
        let toDelete = selectedJobs
        do {
            try await launchdService.deleteJobs(toDelete)
            for job in toDelete {
                selectedJobIDs.remove(job.id)
            }
        } catch {
            errorMessage = "Failed to delete jobs: \(error.localizedDescription)"
        }
    }

    private var selectJobTask: Task<Void, Never>?

    func selectJob(_ job: LaunchdJob) {
        selectedJobIDs = [job.id]

        // Cancel any in-flight selection load
        selectJobTask?.cancel()

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
            await logReader.loadLogs(for: job)
        }
    }

    func saveCurrentJob() async {
        guard let job = selectedJob else { return }
        do {
            try await launchdService.saveJob(job)
        } catch {
            errorMessage = "Failed to save job: \(error.localizedDescription)"
        }
    }
}
