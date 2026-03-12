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
                    switch selectedTab {
                    case .standard:
                        StandardTabView(job: job)
                    case .expert:
                        ExpertTabView()
                    case .xml:
                        XMLTabView()
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
                ContentUnavailableView {
                    Label("No Selection", systemImage: "cursorarrow.click.2")
                } description: {
                    Text("Select a job from the list to view its details.")
                }
                .background(.background)
            }
        }
        .toolbar {
            if let job = store.selectedJob {
                ToolbarItemGroup(placement: .automatic) {
                    quickActionButtons(for: job)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActionButtons(for job: LaunchdJob) -> some View {
        if job.status.isRunning {
            Button {
                Task { await store.unloadJob(job) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .help("Stop this job")

            Button(role: .destructive) {
                Task { await store.forceKillJob(job) }
            } label: {
                Label("Force Kill", systemImage: "xmark.octagon")
            }
            .help("Force kill (SIGKILL)")
        } else {
            Button {
                Task { await store.startJob(job) }
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .help("Start this job")
        }

        if job.isEnabled {
            Button {
                Task { await store.disableJob(job) }
            } label: {
                Label("Disable", systemImage: "pause.circle")
            }
            .help("Disable this job")
        } else {
            Button {
                Task { await store.enableJob(job) }
            } label: {
                Label("Enable", systemImage: "play.circle")
            }
            .help("Enable this job")
        }

        if job.status.isLoaded {
            Button {
                Task { await store.unloadJob(job) }
            } label: {
                Label("Unload", systemImage: "eject")
            }
            .help("Unload this job")
        } else {
            Button {
                Task { await store.loadJob(job) }
            } label: {
                Label("Load", systemImage: "square.and.arrow.down")
            }
            .help("Load this job")
        }

        Button {
            store.selectedJobIDs = [job.id]
            store.showingDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
                .foregroundStyle(.red)
        }
        .help("Delete this job")
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
                    Text("Exit \(exitCode)")
                        .font(.caption.monospaced())
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

            // Runtime details row
            HStack(spacing: 16) {
                statusDetail(label: "Runs", value: info?.runs.map { "\($0)" } ?? "–")

                if case .running = job.status {
                    statusDetail(label: "Up", value: info?.processStartTime.map { uptimeString(since: $0) } ?? "–")
                }

                statusDetail(label: "Last Exit", value: info?.lastExitReason ?? "–")
                statusDetail(label: "Spawn", value: info?.spawnType ?? "–")

                let syslogCount = store.logReader.entries.filter { $0.source == .systemLog }.count
                let errorCount = store.logReader.entries.filter { $0.level == .error || $0.level == .fault }.count
                statusDetail(label: "Logs", value: syslogCount > 0
                    ? (errorCount > 0 ? "\(syslogCount) (\(errorCount) errors)" : "\(syslogCount)")
                    : "–")

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
                        .buttonStyle(.plain)
                        .help("Copy visible logs")
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

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
                    Text(job.label)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }

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

                TextField("Working Directory", text: $editorVM.workingDirectory)
                    .font(.body.monospaced())
            }

            Section("Scheduling") {
                Toggle("Run at Load", isOn: $editorVM.runAtLoad)

                Toggle("Keep Alive", isOn: $editorVM.keepAlive)

                TextField("Start Interval (seconds)", value: $editorVM.startInterval, format: .number)
            }

            Section("Logging") {
                TextField("Standard Out Path", text: $editorVM.standardOutPath)
                    .font(.body.monospaced())

                TextField("Standard Error Path", text: $editorVM.standardErrorPath)
                    .font(.body.monospaced())
            }

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
                    .buttonStyle(.plain)
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

            SyntaxHighlightingTextEditor(text: $xmlEditor.xmlText)
        }
    }
}

// MARK: - Syntax Highlighting Text Editor

struct SyntaxHighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String

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
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel("XML plist editor")

        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
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
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            // Base style
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: fullRange)

            let colors = XMLSyntaxColors(isDark: isDark)

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
    let tag: NSColor
    let attribute: NSColor
    let string: NSColor
    let comment: NSColor
    let declaration: NSColor
    let bracket: NSColor

    init(isDark: Bool) {
        if isDark {
            tag = NSColor(red: 0.47, green: 0.67, blue: 0.98, alpha: 1)        // blue
            attribute = NSColor(red: 0.59, green: 0.84, blue: 0.99, alpha: 1)   // light blue
            string = NSColor(red: 0.95, green: 0.54, blue: 0.46, alpha: 1)      // salmon
            comment = NSColor(red: 0.42, green: 0.48, blue: 0.38, alpha: 1)     // muted green
            declaration = NSColor(red: 0.68, green: 0.51, blue: 0.78, alpha: 1) // purple
            bracket = NSColor.secondaryLabelColor
        } else {
            tag = NSColor(red: 0.11, green: 0.28, blue: 0.65, alpha: 1)         // dark blue
            attribute = NSColor(red: 0.30, green: 0.45, blue: 0.65, alpha: 1)   // steel blue
            string = NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1)      // red
            comment = NSColor(red: 0.33, green: 0.42, blue: 0.19, alpha: 1)     // olive green
            declaration = NSColor(red: 0.44, green: 0.22, blue: 0.58, alpha: 1) // purple
            bracket = NSColor.secondaryLabelColor
        }
    }
}

#Preview {
    DetailView()
        .environment(AppStore())
}
