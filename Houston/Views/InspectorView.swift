import SwiftUI
import Models
import JobAnalyzer

struct InspectorView: View {
    let job: LaunchdJob
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status Section
                InspectorSection("Status") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: statusSymbol)
                                .foregroundStyle(statusColor)
                            Text(statusLabel)
                                .font(.headline)
                                .foregroundStyle(statusColor)
                        }

                        switch job.status {
                        case .running(let pid):
                            LabeledContent("PID") {
                                Text("\(pid, format: .number.grouping(.never))")
                                    .font(.body.monospaced())
                            }
                        case .loaded(let lastExitCode):
                            if let exitCode = lastExitCode {
                                LabeledContent("Last Exit Code") {
                                    Text("\(exitCode)")
                                        .font(.body.monospaced())
                                        .foregroundStyle(exitCode == 0 ? Color.primary : Color.red)
                                }
                            }
                        case .unloaded:
                            EmptyView()
                        case .error(let message):
                            LabeledContent("Error") {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        LabeledContent("Enabled") {
                            Text(job.isEnabled ? "Yes" : "No")
                                .foregroundStyle(job.isEnabled ? .green : .red)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Quick Actions Section
                InspectorSection("Quick Actions") {
                    VStack(spacing: 8) {
                        if job.status.isRunning {
                            Button {
                                Task { await store.unloadJob(job) }
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)

                            Button(role: .destructive) {
                                Task { await store.forceKillJob(job) }
                            } label: {
                                Label("Force Kill", systemImage: "xmark.octagon")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        } else {
                            Button {
                                Task { await store.startJob(job) }
                            } label: {
                                Label("Start", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        }

                        if job.isEnabled {
                            Button {
                                Task { await store.disableJob(job) }
                            } label: {
                                Label("Disable", systemImage: "pause.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        } else {
                            Button {
                                Task { await store.enableJob(job) }
                            } label: {
                                Label("Enable", systemImage: "play.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        }

                        if job.status.isLoaded {
                            Button(role: .destructive) {
                                Task { await store.unloadJob(job) }
                            } label: {
                                Label("Unload", systemImage: "eject")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        } else {
                            Button {
                                Task { await store.loadJob(job) }
                            } label: {
                                Label("Load", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        }
                    }
                    .padding(10)
                }

                // Analysis Section
                InspectorSection("Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        if store.currentAnalysisResults.isEmpty {
                            AnalysisRow(
                                severity: .ok,
                                message: "No issues detected"
                            )
                        } else {
                            ForEach(store.currentAnalysisResults) { result in
                                AnalysisRow(
                                    severity: analysisSeverity(from: result.severity),
                                    message: result.title
                                )
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // File Info Section
                InspectorSection("File Info") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Path")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(job.plistURL.path)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }

                        if let attrs = try? FileManager.default.attributesOfItem(atPath: job.plistURL.path) {
                            if let modDate = attrs[.modificationDate] as? Date {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Modified")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(modDate, style: .date)
                                        .font(.caption)
                                }
                            }

                            if let fileSize = attrs[.size] as? UInt64 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Size")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
        }
        .background(.background)
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

    private func analysisSeverity(from severity: AnalysisResult.Severity) -> AnalysisSeverity {
        switch severity {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        }
    }
}

// MARK: - Analysis Row

enum AnalysisSeverity {
    case ok, info, warning, error

    var color: Color {
        switch self {
        case .ok: return .green
        case .info: return .blue
        case .warning: return .yellow
        case .error: return .red
        }
    }

    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

struct AnalysisRow: View {
    let severity: AnalysisSeverity
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: severity.symbol)
                .foregroundStyle(severity.color)
                .font(.caption)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            GroupBox {
                content
            }
        }
    }
}

#Preview {
    InspectorView(job: LaunchdJob(
        label: "com.example.test",
        domain: .userAgent,
        plistURL: URL(fileURLWithPath: "/tmp/com.example.test.plist"),
        status: .running(pid: 1234),
        isEnabled: true
    ))
    .environment(AppStore())
    .frame(width: 280, height: 600)
}
