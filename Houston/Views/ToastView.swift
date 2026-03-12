import SwiftUI

struct Toast: Equatable {
    enum Style {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: .green
            case .error: .red
            case .info: .blue
            }
        }
    }

    let style: Style
    let message: String
    let id: UUID = UUID()

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.style.icon)
                .foregroundStyle(toast.style.color)
                .font(.body)

            Text(toast.message)
                .font(.body)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

struct ToastContainerModifier: ViewModifier {
    let toast: Toast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast)
                    .padding(.bottom, 20)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.35), value: toast)
        .onChange(of: toast) { _, newToast in
            if let newToast {
                AccessibilityNotification.Announcement(newToast.message).post()
            }
        }
    }
}

extension View {
    func toast(_ toast: Toast?) -> some View {
        modifier(ToastContainerModifier(toast: toast))
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(toast: Toast(style: .success, message: "Job enabled successfully"))
        ToastView(toast: Toast(style: .error, message: "Failed to load job"))
        ToastView(toast: Toast(style: .info, message: "Copied to clipboard"))
    }
    .padding(40)
}
