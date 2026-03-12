import SwiftUI
import Models
import LogViewer

struct LogViewerView: View {
    let job: LaunchdJob
    @Environment(AppStore.self) private var store

    @State private var autoScroll: Bool = true

    var body: some View {
        @Bindable var logReader = store.logReader

        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Source", selection: $logReader.activeSource) {
                    ForEach(LogEntry.LogSource.allCases, id: \.self) { source in
                        Text(sourceDisplayName(source)).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                TextField("Filter", text: $logReader.filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Toggle(isOn: $autoScroll) {
                    Image(systemName: "arrow.down.to.line")
                }
                .toggleStyle(.button)
                .help("Auto-scroll to bottom")

                Button {
                    logReader.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear log output")

                Button {
                    Task { await logReader.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh logs")
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Log content area
            if store.logReader.isReading {
                ProgressView("Loading logs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let entries = store.logReader.filteredEntries
                ScrollView {
                    if entries.isEmpty {
                        Text("No log output available.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(entries) { entry in
                                LogEntryRow(entry: entry)
                            }
                        }
                        .padding(8)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private func sourceDisplayName(_ source: LogEntry.LogSource) -> String {
        switch source {
        case .stdout: return "stdout"
        case .stderr: return "stderr"
        case .systemLog: return "System Log"
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let timestamp = entry.timestamp {
                Text(timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 90, alignment: .leading)
            }

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(levelColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .secondary
        case .info: return .primary
        case .notice: return .blue
        case .warning: return .yellow
        case .error: return .red
        case .fault: return .red
        }
    }
}

#Preview {
    LogViewerView(job: LaunchdJob(
        label: "com.example.test",
        domain: .userAgent,
        plistURL: URL(fileURLWithPath: "/tmp/com.example.test.plist"),
        status: .running(pid: 1234),
        isEnabled: true
    ))
    .environment(AppStore())
    .frame(width: 600, height: 250)
}
