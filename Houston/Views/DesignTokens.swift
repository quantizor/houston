import SwiftUI
import Models
import LogViewer
import PlistEditor

// MARK: - JobStatus UI

extension JobStatus {
    var color: Color {
        switch self {
        case .running: .green
        case .loaded: .orange
        case .unloaded: .gray
        case .error: .red
        }
    }

    var symbol: String {
        switch self {
        case .running: "circle.fill"
        case .loaded: "circle.lefthalf.filled"
        case .unloaded: "circle"
        case .error: "exclamationmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .running: "Running"
        case .loaded: "Loaded"
        case .unloaded: "Not Loaded"
        case .error: "Error"
        }
    }
}

// MARK: - AnalysisResult.Severity UI

extension AnalysisResult.Severity {
    var color: Color {
        switch self {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    var icon: String {
        switch self {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }
}

// MARK: - LogEntry.LogLevel UI

extension LogEntry.LogLevel {
    var color: Color {
        switch self {
        case .fault: .red
        case .error: .red
        case .warning: .orange
        case .notice: .blue
        case .info: .primary
        case .debug: .secondary
        }
    }
}

// MARK: - PlistValidator.ValidationSeverity UI

extension PlistValidator.ValidationSeverity {
    var color: Color {
        switch self {
        case .error: .red
        case .warning: .orange
        }
    }

    var icon: String {
        switch self {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Reusable Components

/// Capsule-shaped pill for status labels (e.g. "Disabled", "Running")
struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Rounded-rectangle badge for type/category tags
struct TagBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}
