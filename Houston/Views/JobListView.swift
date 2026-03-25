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
    @FocusState private var isSearchFocused: Bool

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
        mainContent
            .toolbar { toolbarItems }
            .sheet(isPresented: $showingCreateSheet) { CreateJobSheet() }
            .navigationTitle("")
            .modifier(KeyboardShortcutsModifier(
                isSearchFocused: $isSearchFocused,
                searchText: store.searchText,
                clearSearch: { store.searchText = "" }
            ))
            .onChange(of: store.selectedJobIDs) { _, newValue in
                handleSelectionChange(newValue)
            }
    }

    private func handleSelectionChange(_ newValue: Set<String>) {
        if newValue.count == 1, let id = newValue.first,
           let job = store.jobs.first(where: { $0.id == id }) {
            store.selectJob(job)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if store.isLoading {
            ProgressView("Loading jobs...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            jobListContent
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { showingCreateSheet = true } label: {
                Label("New Job", systemImage: "plus")
            }
            .buttonStyle(.glass)
            .keyboardShortcut("n", modifiers: .command)
        }
        ToolbarItem(placement: .automatic) {
            sortMenu
        }
    }

    private var sortMenu: some View {
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
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOrder.rawValue)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .help("Sort jobs")
    }

    private var searchBar: some View {
        @Bindable var store = store
        return HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search by name, vendor, or description...", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isSearchFocused)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var jobListContent: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            searchBar

            if sortedJobs.isEmpty {
                ContentUnavailableView {
                    Label("No Jobs Found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try adjusting your search or filter criteria.")
                }
            } else {
                List(selection: $store.selectedJobIDs) {
                    ForEach(sortedJobs) { job in
                        jobRow(job: job, store: store)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
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
                        store.showToast(.info, "PID copied")
                    } label: {
                        Label("Copy PID (\(pid))", systemImage: "doc.on.doc")
                    }
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(job.label, forType: .string)
                    store.showToast(.info, "Label copied")
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
                    if !store.selectedJobIDs.contains(job.id) {
                        store.selectedJobIDs = [job.id]
                    }
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
            Image(systemName: job.status.symbol)
                .foregroundStyle(job.status.color)
                .font(.caption2)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName)
                    .font(.body.monospaced())
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.status.label)
                        .font(.caption)
                        .foregroundStyle(job.status.color)

                    if case .running(let pid) = job.status {
                        Text("PID \(pid, format: .number.grouping(.never))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !job.isEnabled {
                        StatusPill(label: "Disabled", color: .red)
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
        .hoverHighlight()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [job.displayName, job.status.label]
        if case .running(let pid) = job.status {
            parts.append("PID \(pid)")
        }
        if !job.isEnabled {
            parts.append("Disabled")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Create Job Sheet

enum JobTemplate: String, CaseIterable, Identifiable {
    case blank = "Blank"
    case script = "Run Script"
    case daemon = "Background Daemon"
    case scheduled = "Scheduled Task"
    case watcher = "File Watcher"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .blank: return "Empty job — configure everything manually"
        case .script: return "Run a shell script at login"
        case .daemon: return "Long-running background process that auto-restarts"
        case .scheduled: return "Run a command on a recurring schedule"
        case .watcher: return "Run a command when specific paths change"
        }
    }

    var icon: String {
        switch self {
        case .blank: return "doc"
        case .script: return "terminal"
        case .daemon: return "gearshape.2"
        case .scheduled: return "clock"
        case .watcher: return "eye"
        }
    }

    var program: String {
        switch self {
        case .blank: return ""
        case .script: return "/bin/bash"
        case .daemon: return ""
        case .scheduled: return "/bin/bash"
        case .watcher: return "/bin/bash"
        }
    }

    var arguments: String {
        switch self {
        case .blank: return ""
        case .script: return "-c /path/to/script.sh"
        case .daemon: return ""
        case .scheduled: return "-c /path/to/task.sh"
        case .watcher: return "-c /path/to/on-change.sh"
        }
    }

    var runAtLoad: Bool {
        switch self {
        case .daemon: return true
        default: return false
        }
    }

    var keepAlive: Bool {
        switch self {
        case .daemon: return true
        default: return false
        }
    }
}

struct CreateJobSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: JobTemplate = .blank
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
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Template") {
                    Picker("Start from", selection: $selectedTemplate) {
                        ForEach(JobTemplate.allCases) { template in
                            Label(template.rawValue, systemImage: template.icon).tag(template)
                        }
                    }

                    Text(selectedTemplate.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Identity") {
                    TextField("Label (e.g. com.mycompany.myagent)", text: $label)
                        .font(.body.monospaced())

                    Picker("Domain", selection: $domain) {
                        ForEach(JobDomainType.allCases.filter { !$0.isReadOnly }) { d in
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
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
            }
            .padding()
        }
        .onChange(of: selectedTemplate) { _, template in
            program = template.program
            arguments = template.arguments
            runAtLoad = template.runAtLoad
            keepAlive = template.keepAlive
        }
        .frame(width: 480, height: 520)
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

// MARK: - Keyboard Shortcuts

private struct KeyboardShortcutsModifier: ViewModifier {
    var isSearchFocused: FocusState<Bool>.Binding
    let searchText: String
    let clearSearch: () -> Void

    func body(content: Content) -> some View {
        content
            .background {
                // Hidden button to capture Cmd+F
                Button("") {
                    isSearchFocused.wrappedValue = true
                }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            }
            .onKeyPress(.escape) {
                guard isSearchFocused.wrappedValue else { return .ignored }
                if searchText.isEmpty {
                    isSearchFocused.wrappedValue = false
                } else {
                    clearSearch()
                }
                return .handled
            }
    }
}

#Preview {
    JobListView()
        .environment(AppStore())
}
