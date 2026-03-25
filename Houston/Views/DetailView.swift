import SwiftUI
import Models
import PlistEditor
import LogViewer

enum DetailTab: String, CaseIterable {
    case standard = "Standard"
    case expert = "Expert"
    case xml = "XML"

    var systemImage: String {
        switch self {
        case .standard: return "list.bullet.rectangle"
        case .expert: return "tree"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct DetailView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: DetailTab = .standard

    var body: some View {
        ZStack {
            if let job = store.selectedJob {
                VStack(spacing: 0) {
                    // Status header
                    JobStatusHeader(job: job)

                    Divider()

                    // Log preview
                    LogPreview(job: job)

                    Divider()

                    // Tab bar
                    Picker("View", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.systemImage)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Divider()

                    // Tab content
                    Group {
                        switch selectedTab {
                        case .standard:
                            StandardTabView(job: job)
                        case .expert:
                            ExpertTabView()
                        case .xml:
                            XMLTabView()
                        }
                    }
                    .frame(maxHeight: .infinity)

                    if job.isReadOnly {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text("This is a system service and cannot be modified")
                                .font(.caption)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.3))
                    }
                }
            }

            // Overlay messages when no single selection
            if store.selectedJobIDs.count > 1 {
                ContentUnavailableView {
                    Label("\(store.selectedJobIDs.count) Jobs Selected", systemImage: "checkmark.circle")
                } description: {
                    Text("Select a single job to view its details, or press Delete to remove the selected jobs.")
                }
                .background(.background)
            } else if store.selectedJob == nil {
                DashboardView()
                    .background(.background)
            }
        }
        .toolbar {
            if let job = store.selectedJob {
                ToolbarItemGroup(placement: .automatic) {
                    Group {
                        quickActionButtons(for: job)

                        Button {
                            NSWorkspace.shared.selectFile(job.plistURL.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.glass)
                        .help("Reveal plist in Finder")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActionButtons(for job: LaunchdJob) -> some View {
        if !job.isReadOnly {
            if job.status.isRunning {
                Button {
                    Task { await store.unloadJob(job) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop this job")
                .buttonStyle(.glassProminent)

                Button(role: .destructive) {
                    Task { await store.forceKillJob(job) }
                } label: {
                    Label("Force Kill", systemImage: "xmark.octagon")
                }
                .help("Force kill (SIGKILL)")
                .buttonStyle(.glass)
            } else {
                Button {
                    Task { await store.startJob(job) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Start this job")
                .buttonStyle(.glass)
            }

            if job.isEnabled {
                Button {
                    Task { await store.disableJob(job) }
                } label: {
                    Label("Disable", systemImage: "pause.circle")
                }
                .help("Disable this job")
                .buttonStyle(.glass)
            } else {
                Button {
                    Task { await store.enableJob(job) }
                } label: {
                    Label("Enable", systemImage: "play.circle")
                }
                .help("Enable this job")
                .buttonStyle(.glass)
            }

            if job.status.isLoaded {
                Button {
                    Task { await store.unloadJob(job) }
                } label: {
                    Label("Unload", systemImage: "eject")
                }
                .help("Unload this job")
                .buttonStyle(.glass)
            } else {
                Button {
                    Task { await store.loadJob(job) }
                } label: {
                    Label("Load", systemImage: "square.and.arrow.down")
                }
                .help("Load this job")
                .buttonStyle(.glass)
            }

            Button {
                store.selectedJobIDs = [job.id]
                store.showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .help("Delete this job")
            .buttonStyle(.glass)
        }
    }
}

// MARK: - Job Status Header

struct JobStatusHeader: View {
    let job: LaunchdJob
    @Environment(AppStore.self) private var store

    private var info: ServiceInfo? { store.currentServiceInfo }

    var body: some View {
        VStack(spacing: 0) {
            // Primary status row
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: job.status.symbol)
                        .foregroundStyle(job.status.color)
                        .font(.caption2)
                    Text(job.status.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(job.status.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(job.status.label)")

                if case .running(let pid) = job.status {
                    Text("PID \(pid, format: .number.grouping(.never))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                if case .loaded(let exitCode) = job.status, let exitCode {
                    HStack(spacing: 4) {
                        Text("Exit \(exitCode)")
                            .font(.caption.monospaced())
                        if exitCode != 0, let explanation = ExitCodeInfo.explanation(for: exitCode) {
                            Text("— \(explanation)")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(exitCode == 0 ? Color.secondary : Color.red)
                }

                if case .error(let message) = job.status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                if !job.isEnabled {
                    StatusPill(label: "Disabled", color: .red)
                }

                Spacer()
            }

            // Analysis issues
            if !store.currentAnalysisResults.isEmpty {
                ForEach(store.currentAnalysisResults) { result in
                    HStack(spacing: 6) {
                        Image(systemName: result.severity.icon)
                            .foregroundStyle(result.severity.color)
                            .font(.caption2)
                        Text(result.title)
                            .font(.caption)
                        if let key = result.key {
                            Text(key)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if let suggestion = result.suggestion {
                            Text(suggestion)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Diagnostic summary
            if let diagnosis = JobDiagnostic.diagnose(
                job: job,
                serviceInfo: info,
                analysisResults: store.currentAnalysisResults
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text(diagnosis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }

            // Runtime details row
            HStack(spacing: 16) {
                if store.isLoadingDetail {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading details...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    statusDetail(label: "Runs", value: info?.runs.map { "\($0)" } ?? "–")

                    if case .running = job.status {
                        statusDetail(label: "Up", value: info?.processStartTime.map { uptimeString(since: $0) } ?? "–")
                    }

                    statusDetail(label: "Last Exit", value: info?.lastExitReason ?? "–")
                    statusDetail(label: "Spawn", value: info?.spawnType ?? "–")

                    if let activeCount = info?.activeCount, activeCount > 0 {
                        statusDetail(label: "Active", value: "\(activeCount)")
                    }
                    if let forks = info?.forks {
                        statusDetail(label: "Forks", value: "\(forks)")
                    }
                    if let execs = info?.execs {
                        statusDetail(label: "Execs", value: "\(execs)")
                    }

                    let syslogCount = store.logReader.entries.filter { $0.source == .systemLog }.count
                    let errorCount = store.logReader.entries.filter { $0.level == .error || $0.level == .fault }.count
                    statusDetail(label: "Logs", value: syslogCount > 0
                        ? (errorCount > 0 ? "\(syslogCount) (\(errorCount) errors)" : "\(syslogCount)")
                        : "–")
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
    }

    private func statusDetail(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func hasRuntimeDetails(_ info: ServiceInfo) -> Bool {
        info.runs != nil || info.processStartTime != nil || info.lastExitReason != nil || info.spawnType != nil
    }

    private func uptimeString(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 {
            let h = Int(interval / 3600)
            let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h \(m)m"
        }
        let d = Int(interval / 86400)
        let h = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        return "\(d)d \(h)h"
    }

}

// MARK: - Log Preview

struct LogPreview: View {
    let job: LaunchdJob
    @Environment(AppStore.self) private var store
    @State private var isExpanded: Bool = false
    @State private var hasAutoExpanded: Bool = false
    @State private var refreshTimer: Timer?

    private let maxEntries = 20

    private var recentEntries: [LogEntry] {
        Array(store.logReader.entries.suffix(maxEntries))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "terminal")
                        .font(.caption)

                    Text("Logs")
                        .font(.caption.weight(.medium))

                    if !store.logReader.entries.isEmpty {
                        Text("\(store.logReader.entries.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }

                    if job.status.isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    }

                    Spacer()

                    if isExpanded && !recentEntries.isEmpty {
                        Button {
                            copyLogs()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy visible logs")
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .hoverHighlight()
            }
            .buttonStyle(.borderless)

            if isExpanded {
                if recentEntries.isEmpty {
                    Text("No log entries found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.3))
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(recentEntries) { entry in
                                    logLine(entry)
                                        .id(entry.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 140)
                        .onChange(of: store.logReader.entries.count) {
                            if let last = recentEntries.last {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.3))
                    .textSelection(.enabled)
                }
            }
        }
        .onAppear { startAutoRefresh() }
        .onDisappear { stopAutoRefresh() }
        .onChange(of: store.logReader.entries.isEmpty) { _, isEmpty in
            if !isEmpty && !hasAutoExpanded {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                hasAutoExpanded = true
            }
        }
        .onChange(of: job.id) {
            hasAutoExpanded = false
            isExpanded = !store.logReader.entries.isEmpty
        }
    }

    private func logLine(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let ts = entry.timestamp {
                Text(ts, format: .dateTime.hour().minute().second())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 60, alignment: .leading)
            }

            Text(entry.message)
                .font(.caption.monospaced())
                .foregroundStyle(entry.level.color)
                .lineLimit(2)
        }
        .padding(.vertical, 1)
    }

    private func copyLogs() {
        let text = recentEntries.map { entry in
            let ts = entry.timestamp.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            return "\(ts) [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        store.showToast(.info, "Logs copied")
    }

    private func startAutoRefresh() {
        guard job.status.isRunning else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in
                await store.logReader.refresh()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Standard Tab

struct StandardTabView: View {
    let job: LaunchdJob
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var editorVM = store.editorViewModel.standardEditor

        Form {
            Section("Identity") {
                LabeledContent("Label") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(job.label)
                            .font(.body.monospaced())
                            .textSelection(.enabled)

                        if let description = AppleServiceInfo.description(for: job.label) {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .help(PlistKey.lookup("Label")?.description ?? "")

                LabeledContent("Domain") {
                    Text(job.domain.displayName)
                        .font(.body)
                }

                LabeledContent("Plist Path") {
                    Text(job.plistURL.path)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                }
            }

            Section("Execution") {
                TextField("Program", text: $editorVM.program)
                    .font(.body.monospaced())
                    .help(PlistKey.lookup("Program")?.description ?? "")

                LabeledContent("Arguments") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(editorVM.programArguments.enumerated()), id: \.offset) { index, arg in
                            Text(arg)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if editorVM.programArguments.isEmpty {
                            Text("None")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .help(PlistKey.lookup("ProgramArguments")?.description ?? "")

                TextField("Working Directory", text: $editorVM.workingDirectory)
                    .font(.body.monospaced())
                    .help(PlistKey.lookup("WorkingDirectory")?.description ?? "")
            }
            .disabled(job.isReadOnly)

            Section("Scheduling") {
                Toggle("Run at Load", isOn: $editorVM.runAtLoad)
                    .help(PlistKey.lookup("RunAtLoad")?.description ?? "")

                Toggle("Keep Alive", isOn: $editorVM.keepAlive)
                    .help(PlistKey.lookup("KeepAlive")?.description ?? "")

                TextField("Start Interval (seconds)", value: $editorVM.startInterval, format: .number)
                    .help(PlistKey.lookup("StartInterval")?.description ?? "")

                DisclosureGroup("Calendar Interval") {
                    calendarIntervalField("Month (1–12)", value: $editorVM.calendarMonth)
                    calendarIntervalField("Day (1–31)", value: $editorVM.calendarDay)
                    calendarIntervalField("Weekday (0–7, 0=Sun)", value: $editorVM.calendarWeekday)
                    calendarIntervalField("Hour (0–23)", value: $editorVM.calendarHour)
                    calendarIntervalField("Minute (0–59)", value: $editorVM.calendarMinute)
                }
                .help(PlistKey.lookup("StartCalendarInterval")?.description ?? "")

                // Schedule preview — surfaces ScheduleInfo for any job with scheduling configured
                if let scheduleDesc = ScheduleInfo.description(
                    startInterval: job.startInterval,
                    startCalendarInterval: job.startCalendarInterval
                ) {
                    LabeledContent("Schedule") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(scheduleDesc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            if let nextRun = ScheduleInfo.nextRunString(
                                startInterval: job.startInterval,
                                startCalendarInterval: job.startCalendarInterval
                            ) {
                                Text(nextRun)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .disabled(job.isReadOnly)

            Section("Logging") {
                TextField("Standard Out Path", text: $editorVM.standardOutPath)
                    .font(.body.monospaced())
                    .help(PlistKey.lookup("StandardOutPath")?.description ?? "")

                TextField("Standard Error Path", text: $editorVM.standardErrorPath)
                    .font(.body.monospaced())
                    .help(PlistKey.lookup("StandardErrorPath")?.description ?? "")
            }
            .disabled(job.isReadOnly)

            Section("Environment Variables") {
                ForEach(Array(editorVM.environmentVariables.enumerated()), id: \.offset) { index, pair in
                    HStack(spacing: 8) {
                        TextField("Key", text: Binding(
                            get: { editorVM.environmentVariables[index].key },
                            set: { editorVM.environmentVariables[index].key = $0 }
                        ))
                        .font(.body.monospaced())
                        .frame(maxWidth: 200)

                        Text("=")
                            .foregroundStyle(.tertiary)

                        TextField("Value", text: Binding(
                            get: { editorVM.environmentVariables[index].value },
                            set: { editorVM.environmentVariables[index].value = $0 }
                        ))
                        .font(.body.monospaced())

                        Button(role: .destructive) {
                            editorVM.environmentVariables.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove variable")
                    }
                }

                Button {
                    editorVM.environmentVariables.append((key: "", value: ""))
                } label: {
                    Label("Add Variable", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .help(PlistKey.lookup("EnvironmentVariables")?.description ?? "")
            .disabled(job.isReadOnly)

            if !editorVM.validationErrors.isEmpty {
                Section("Validation Issues") {
                    ForEach(editorVM.validationErrors) { error in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: error.severity.icon)
                                .foregroundStyle(error.severity.color)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.key)
                                    .font(.caption.monospaced().weight(.medium))
                                Text(error.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.visible)
    }

    private func calendarIntervalField(_ label: String, value: Binding<Int?>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("–", value: value, format: .number)
                .font(.body.monospaced())
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Expert Tab

struct ExpertTabView: View {
    @Environment(AppStore.self) private var store

    private var validationErrors: [PlistValidator.ValidationError] {
        guard let dict = store.editorViewModel.expertEditor.toDictionary() else { return [] }
        return PlistValidator().validate(dict)
    }

    var body: some View {
        Group {
            if let rootNode = store.editorViewModel.expertEditor.rootNode {
                List {
                    if !validationErrors.isEmpty {
                        Section {
                            ForEach(validationErrors) { error in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: error.severity.icon)
                                        .foregroundStyle(error.severity.color)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(error.key)
                                            .font(.caption.monospaced().weight(.medium))
                                        Text(error.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Validation Issues")
                        }
                    }

                    if rootNode.children.isEmpty {
                        ContentUnavailableView {
                            Label("Empty Plist", systemImage: "doc")
                        } description: {
                            Text("This plist has no keys. Add one to get started.")
                        }
                    } else {
                        OutlineGroup(rootNode.children, children: \.optionalChildren) { node in
                            PlistNodeRow(node: node, editor: store.editorViewModel.expertEditor)
                        }
                    }

                    Button {
                        store.editorViewModel.expertEditor.addChild(
                            to: rootNode.id,
                            key: "NewKey",
                            value: .string("")
                        )
                    } label: {
                        Label("Add Key", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                }
                .listStyle(.inset)
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "tree")
                } description: {
                    Text("Select a job to view its plist tree.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(store.selectedJob?.isReadOnly == true)
    }
}

// MARK: - Plist Node Row

struct PlistNodeRow: View {
    @Bindable var node: PlistNode
    let editor: ExpertEditorViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: nodeIcon)
                .foregroundStyle(nodeColor)
                .font(.caption)
                .frame(width: 16)

            Text(node.key)
                .font(.body.monospaced().weight(.medium))
                .textSelection(.enabled)

            TagBadge(label: node.value.typeDescription, color: .blue)

            switch node.value {
            case .boolean(let b):
                Toggle(node.key, isOn: Binding(
                    get: { b },
                    set: { node.value = .boolean($0); editor.hasUnsavedChanges = true }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

            case .string(let s):
                TextField("Value", text: Binding(
                    get: { s },
                    set: { node.value = .string($0); editor.hasUnsavedChanges = true }
                ))
                .font(.body.monospaced())
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)

            case .integer(let n):
                TextField("Value", text: Binding(
                    get: { "\(n)" },
                    set: { if let v = Int($0) { node.value = .integer(v); editor.hasUnsavedChanges = true } }
                ))
                .font(.body.monospaced())
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)

            case .real(let d):
                TextField("Value", text: Binding(
                    get: { "\(d)" },
                    set: { if let v = Double($0) { node.value = .real(v); editor.hasUnsavedChanges = true } }
                ))
                .font(.body.monospaced())
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)

            default:
                if !node.value.displayValue.isEmpty {
                    Text(node.value.displayValue)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .help(PlistKey.lookup(node.key)?.description ?? "")
        .contextMenu {
            Button("Copy Key") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.key, forType: .string)
            }

            if !node.value.displayValue.isEmpty {
                Button("Copy Value") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.value.displayValue, forType: .string)
                }
            }

            if node.parent != nil {
                Divider()
                Button("Delete", role: .destructive) {
                    editor.removeNode(node.id)
                }
            }
        }
    }

    private var nodeIcon: String {
        switch node.value {
        case .dictionary: return "folder"
        case .array: return "list.number"
        case .boolean: return "checkmark.circle"
        case .string: return "textformat"
        case .integer, .real: return "number"
        case .date: return "calendar"
        case .data: return "doc"
        }
    }

    private var nodeColor: Color {
        switch node.value {
        case .dictionary: return .blue
        case .array: return .purple
        case .boolean: return .orange
        case .string: return .green
        case .integer, .real: return .teal
        case .date: return .pink
        case .data: return .gray
        }
    }
}

// MARK: - XML Tab

struct XMLTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var xmlEditor = store.editorViewModel.xmlEditor

        VStack(spacing: 0) {
            if let parseError = xmlEditor.parseError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(parseError)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1))

                Divider()
            }

            SyntaxHighlightingTextEditor(
                text: $xmlEditor.xmlText,
                isEditable: store.selectedJob?.isReadOnly != true
            )
        }
    }
}

// MARK: - Syntax Highlighting Text Editor

struct SyntaxHighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isEditable = isEditable
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel("XML plist editor")

        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        textView.isEditable = isEditable
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting()
            textView.selectedRanges = selectedRanges
        }
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightingTextEditor
        weak var textView: NSTextView?
        private var isUpdating = false

        init(_ parent: SyntaxHighlightingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else { return }
            parent.text = textView.string
            applyHighlighting()
        }

        func applyHighlighting() {
            guard let textView, let storage = textView.textStorage else { return }
            isUpdating = true
            defer { isUpdating = false }

            let text = storage.string
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            // Base style
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: fullRange)

            let colors = XMLSyntaxColors()

            // XML comments: <!-- ... -->
            highlight(storage, pattern: "<!--[\\s\\S]*?-->", color: colors.comment, in: text)

            // XML declarations: <?xml ... ?> and <!DOCTYPE ...>
            highlight(storage, pattern: "<[?!][^>]*>", color: colors.declaration, in: text)

            // Tag names: <tagName or </tagName
            highlight(storage, pattern: "(?<=</?)[a-zA-Z][a-zA-Z0-9_.:-]*", color: colors.tag, in: text)

            // Attribute names: word=
            highlight(storage, pattern: "\\b[a-zA-Z_][a-zA-Z0-9_.-]*(?=\\s*=)", color: colors.attribute, in: text)

            // Attribute values: "..."
            highlight(storage, pattern: "\"[^\"]*\"", color: colors.string, in: text)

            // Angle brackets and closing slash
            highlight(storage, pattern: "[<>/?](?=[a-zA-Z/!?])|(?<=[a-zA-Z\"?/])[>]", color: colors.bracket, in: text)

            storage.endEditing()
        }

        private func highlight(_ storage: NSTextStorage, pattern: String, color: NSColor, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)
            for match in regex.matches(in: text, range: range) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
    }
}

private struct XMLSyntaxColors {
    let tag = NSColor.systemBlue
    let attribute = NSColor.systemCyan
    let string = NSColor.systemRed
    let comment = NSColor.systemGreen
    let declaration = NSColor.systemPurple
    let bracket = NSColor.secondaryLabelColor
}

// MARK: - Dashboard (shown when no job is selected)

struct DashboardView: View {
    @Environment(AppStore.self) private var store

    private struct DashboardStats {
        var troubleJobs: [LaunchdJob] = []
        var runningCount = 0
        var total = 0

        var summaryText: String {
            if total == 0 { return "No jobs loaded" }
            if troubleJobs.isEmpty { return "\(runningCount) running, all healthy" }
            let c = troubleJobs.count
            return "\(c) \(c == 1 ? "job needs" : "jobs need") attention"
        }

        var summaryColor: Color {
            if total == 0 { return .secondary }
            return troubleJobs.isEmpty ? .green : .orange
        }
    }

    /// Exit codes that are normal for on-demand services (not user-actionable).
    private static let normalExitCodes: Set<Int> = [
        -9,   // SIGKILL — macOS kills idle on-demand agents
        -15,  // SIGTERM — clean shutdown by launchd
        -2,   // SIGINT — interrupted (normal during logout/restart)
    ]

    private var stats: DashboardStats {
        var s = DashboardStats()
        s.total = store.jobs.count
        for job in store.jobs {
            switch job.status {
            case .running:
                s.runningCount += 1
            case .loaded(let code) where code != nil && code != 0:
                // Skip read-only system jobs with normal exit codes — user can't act on them
                if job.isReadOnly, let c = code, Self.normalExitCodes.contains(c) { continue }
                s.troubleJobs.append(job)
            case .error:
                if job.isReadOnly { continue }
                s.troubleJobs.append(job)
            default: break
            }
        }
        s.troubleJobs.sort { $0.label < $1.label }
        return s
    }

    var body: some View {
        let stats = stats

        VStack(spacing: 0) {
            Spacer()

            // Health summary
            VStack(spacing: 12) {
                Image(systemName: stats.troubleJobs.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(stats.summaryColor)

                Text(stats.summaryText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(stats.summaryColor)
            }
            .padding(.bottom, 20)

            // Trouble jobs
            if !stats.troubleJobs.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Needs Attention")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)

                    ForEach(stats.troubleJobs.prefix(10)) { job in
                        Button {
                            store.selectedJobIDs = [job.id]
                            store.selectJob(job)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: job.status.isLoaded ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(width: 16)

                                Text(job.displayName)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)

                                Text(job.vendor)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)

                                Spacer()

                                Text(troubleDetail(for: job))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if stats.troubleJobs.count > 10 {
                        Text("and \(stats.troubleJobs.count - 10) more...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
            }

            Spacer()

            Text("Select a job to view its details")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func troubleDetail(for job: LaunchdJob) -> String {
        if case .loaded(let code) = job.status, let c = code, c != 0 {
            return ExitCodeInfo.explanation(for: c) ?? "Exit \(c)"
        }
        if case .error(let msg) = job.status {
            return msg
        }
        return ""
    }
}

#Preview {
    DetailView()
        .environment(AppStore())
}
