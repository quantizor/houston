import SwiftUI
import Models
import LaunchdService

enum JobSortOrder: String, CaseIterable {
    case name = "Name"
    case status = "Status"
    case vendor = "Vendor"
}

struct JobListView: View {
    @Environment(AppStore.self) private var store
    @State private var sortOrder: JobSortOrder = .name
    @State private var showingCreateSheet = false

    private var sortedJobs: [LaunchdJob] {
        let filtered = store.filteredJobs
        switch sortOrder {
        case .name:
            return filtered.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .status:
            return filtered.sorted { $0.status.sortPriority < $1.status.sortPriority }
        case .vendor:
            return filtered.sorted {
                let v0 = $0.vendor
                let v1 = $1.vendor
                if v0 == v1 {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return v0.localizedCaseInsensitiveCompare(v1) == .orderedAscending
            }
        }
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading {
                ProgressView("Loading jobs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sortedJobs.isEmpty {
                ContentUnavailableView {
                    Label("No Jobs Found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try adjusting your search or filter criteria.")
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Filter jobs...", text: $store.searchText)
                            .textFieldStyle(.plain)
                            .font(.body)
                        if !store.searchText.isEmpty {
                            Button {
                                store.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    List(selection: $store.selectedJobIDs) {
                        ForEach(sortedJobs) { job in
                            jobRow(job: job, store: store)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
                .onDeleteCommand {
                    if !store.selectedJobIDs.isEmpty {
                        store.showingDeleteConfirmation = true
                    }
                }
                .confirmationDialog(
                    "Delete \(store.selectedJobIDs.count == 1 ? "Job" : "\(store.selectedJobIDs.count) Jobs")?",
                    isPresented: $store.showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task { await store.deleteSelectedJobs() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if store.selectedJobIDs.count == 1, let job = store.selectedJob {
                        Text("This will unload and delete \"\(job.label)\". This action cannot be undone.")
                    } else {
                        Text("This will unload and delete \(store.selectedJobIDs.count) jobs. This action cannot be undone.")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Job", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(JobSortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            if sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOrder.rawValue)
                    }
                    .padding(.horizontal, 2)
                }
                .help("Sort jobs")
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateJobSheet()
        }
        .navigationTitle("")
        .onChange(of: store.selectedJobIDs) { _, newValue in
            if newValue.count == 1, let id = newValue.first,
               let job = store.jobs.first(where: { $0.id == id }) {
                store.selectJob(job)
            }
        }
    }

    @ViewBuilder
    private func jobRow(job: LaunchdJob, store: AppStore) -> some View {
        JobRow(job: job)
            .tag(job.id)
            .contextMenu {
                if job.isEnabled {
                    Button {
                        Task { await store.disableJob(job) }
                    } label: {
                        Label("Disable", systemImage: "pause.circle")
                    }
                } else {
                    Button {
                        Task { await store.enableJob(job) }
                    } label: {
                        Label("Enable", systemImage: "play.circle")
                    }
                }

                if job.status.isLoaded {
                    Button {
                        Task { await store.unloadJob(job) }
                    } label: {
                        Label("Unload", systemImage: "eject")
                    }
                } else {
                    Button {
                        Task { await store.loadJob(job) }
                    } label: {
                        Label("Load", systemImage: "square.and.arrow.down")
                    }
                }

                if case .running = job.status {
                    Button(role: .destructive) {
                        Task { await store.forceKillJob(job) }
                    } label: {
                        Label("Force Kill (SIGKILL)", systemImage: "xmark.octagon")
                    }
                }

                Divider()

                if case .running(let pid) = job.status {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(pid)", forType: .string)
                    } label: {
                        Label("Copy PID (\(pid))", systemImage: "doc.on.doc")
                    }
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(job.label, forType: .string)
                } label: {
                    Label("Copy Label", systemImage: "doc.on.doc")
                }

                Button {
                    NSWorkspace.shared.selectFile(
                        job.plistURL.path,
                        inFileViewerRootedAtPath: ""
                    )
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    store.showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

}

// MARK: - Job Row

struct JobRow: View {
    let job: LaunchdJob

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .font(.system(size: 10))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName)
                    .font(.body.monospaced())
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)

                    if case .running(let pid) = job.status {
                        Text("PID \(pid, format: .number.grouping(.never))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !job.isEnabled {
                        Text("Disabled")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            Text(job.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch job.status {
        case .running: return .green
        case .loaded: return .yellow
        case .unloaded: return .gray
        case .error: return .red
        }
    }

    private var statusSymbol: String {
        switch job.status {
        case .running: return "circle.fill"
        case .loaded: return "circle.lefthalf.filled"
        case .unloaded: return "circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var statusLabel: String {
        switch job.status {
        case .running: return "Running"
        case .loaded: return "Loaded"
        case .unloaded: return "Not Loaded"
        case .error: return "Error"
        }
    }
}

// MARK: - Create Job Sheet

struct CreateJobSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var domain: JobDomainType = .userAgent
    @State private var program = ""
    @State private var arguments = ""
    @State private var runAtLoad = false
    @State private var keepAlive = false
    @State private var isCreating = false
    @State private var error: String?

    private var isValid: Bool {
        !label.isEmpty && (!program.isEmpty || !arguments.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Launch Job")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Identity") {
                    TextField("Label (e.g. com.mycompany.myagent)", text: $label)
                        .font(.body.monospaced())

                    Picker("Domain", selection: $domain) {
                        ForEach(JobDomainType.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                }

                Section("Execution") {
                    TextField("Program path", text: $program)
                        .font(.body.monospaced())

                    TextField("Arguments (space-separated)", text: $arguments)
                        .font(.body.monospaced())
                }

                Section("Scheduling") {
                    Toggle("Run at Load", isOn: $runAtLoad)
                    Toggle("Keep Alive", isOn: $keepAlive)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                if domain.requiresPrivilege {
                    Label("Requires admin privileges", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Create") {
                    Task { await createJob() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
            }
            .padding()
        }
        .frame(width: 480, height: 460)
    }

    private func createJob() async {
        isCreating = true
        defer { isCreating = false }

        var progArgs: [String] = []
        if !program.isEmpty {
            progArgs.append(program)
        }
        if !arguments.isEmpty {
            progArgs.append(contentsOf: arguments.components(separatedBy: " ").filter { !$0.isEmpty })
        }

        do {
            let job = try await store.launchdService.createJob(
                label: label,
                domain: domain,
                programArguments: progArgs
            )

            // Apply scheduling options via the public update+save API
            if runAtLoad || keepAlive {
                var updated = job
                updated.runAtLoad = runAtLoad
                updated.keepAlive = keepAlive
                try await store.launchdService.updateAndSaveJob(updated)
            }

            store.selectedJobIDs = [job.id]
            store.selectJob(job)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    JobListView()
        .environment(AppStore())
}
