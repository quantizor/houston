import SwiftUI
import Models

struct MenuBarWidget: View {
    @Environment(AppStore.self) private var store

    private var runningJobs: [LaunchdJob] {
        Array(store.jobs.filter { $0.status.isRunning }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !runningJobs.isEmpty {
                Section("Running Jobs") {
                    ForEach(runningJobs, id: \.id) { job in
                        Button {
                            Task { await store.unloadJob(job) }
                        } label: {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption2)
                                    .frame(width: 16)

                                Text(job.label)
                                    .font(.body.monospaced())
                                    .lineLimit(1)

                                Spacer()

                                if case .running(let pid) = job.status {
                                    Text("PID \(pid)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityHint("Double-click to stop this job")
                    }
                }

                Divider()
            }

            Section("Quick Actions") {
                Button {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Label("Open Houston", systemImage: "macwindow")
                }

                Button {
                    Task { await store.refreshJobs() }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            HStack {
                Text("Houston v0.1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.jobs.filter { $0.status.isRunning }.count) running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    MenuBarWidget()
        .environment(AppStore())
        .frame(width: 300)
}
