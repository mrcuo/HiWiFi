import SwiftUI

/// A single WiFi network row — displays SSID, signal, security, and crack status
struct WiFiRowView: View {
    let network: WiFiNetwork
    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            SignalIndicator(level: network.signalLevel)
                .frame(width: 24, height: 20)

            // Network info
            VStack(alignment: .leading, spacing: 3) {
                Text(network.ssid)
                    .font(.body.bold())
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(
                        text: network.security.rawValue,
                        style: securityBadgeStyle
                    )

                    Text("CH \(network.channel)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Crack status indicator
            statusIcon
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch network.status {
        case .idle:
            EmptyView()
        case .cracking:
            ProgressView()
                .controlSize(.mini)
                .transition(.opacity)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
                .transition(.opacity)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
                .symbolEffect(.bounce, options: .nonRepeating)
                .transition(.opacity)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .transition(.opacity)
        }
    }

    // MARK: - Helpers

    private var securityBadgeStyle: StatusBadge.Style {
        switch network.security {
        case .wpa3: return .error
        case .wpa2: return .warning
        case .wep: return .success
        case .open: return .success
        case .unknown: return .default
        }
    }
}
