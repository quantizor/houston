import SwiftUI
import Models
import PlistEditor

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
    @State private var showInspector: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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
                if let job = store.selectedJob {
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
            .opacity(store.selectedJob != nil ? 1 : 0)

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
        .inspector(isPresented: $showInspector) {
            if let job = store.selectedJob {
                InspectorView(job: job)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation { showInspector.toggle() }
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Toggle inspector panel")
            }
        }
        .onChange(of: store.selectedJob?.id) { _, newValue in
            showInspector = newValue != nil
        }
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
                }

                LabeledContent("Plist Path") {
                    Text(job.plistURL.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
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
                            Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(error.severity == .error ? .red : .yellow)
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
                                    Image(systemName: error.severity == .error
                                          ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(error.severity == .error ? .red : .yellow)
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

            Text(node.value.typeDescription)
                .font(.caption2.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.blue)

            switch node.value {
            case .boolean(let b):
                Toggle("", isOn: Binding(
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

        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator

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
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)

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
