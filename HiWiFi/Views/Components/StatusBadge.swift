import SwiftUI

/// Compact capsule-shaped badge for security types and status labels
struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    var style: Style = .default

    // MARK: - Style Enum

    enum Style {
        case `default`  // Gray
        case success    // Green
        case warning    // Orange
        case error      // Red

        var foregroundColor: Color {
            switch self {
            case .default: return .secondary
            case .success: return .green
            case .warning: return .orange
            case .error:   return .red
            }
        }

        var backgroundColor: Color {
            switch self {
            case .default: return .gray.opacity(0.12)
            case .success: return .green.opacity(0.12)
            case .warning: return .orange.opacity(0.12)
            case .error:   return .red.opacity(0.12)
            }
        }

        /// Default icon per style
        var defaultIcon: String {
            switch self {
            case .default: return "questionmark.circle"
            case .success: return "checkmark.shield"
            case .warning: return "exclamationmark.shield"
            case .error:   return "lock.shield"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon ?? style.defaultIcon)
                .font(.system(size: 8, weight: .bold))

            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(style.foregroundColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(style.backgroundColor, in: Capsule())
    }
}
