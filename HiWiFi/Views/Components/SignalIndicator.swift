import SwiftUI

/// WiFi signal strength indicator — 4 ascending bars, color-coded by level
struct SignalIndicator: View {
    /// Signal level: 0 (weakest) to 3 (strongest)
    let level: Int

    // MARK: - Constants

    private let barCount = 4
    private let barSpacing: CGFloat = 2
    private let barWidth: CGFloat = 4
    private let cornerRadius: CGFloat = 1.5

    // MARK: - Body

    var body: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(barColor(for: index))
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .animation(.smooth(duration: 0.3), value: level)
    }

    // MARK: - Bar Calculations

    /// Height scales linearly: bar 0 is shortest, bar 3 is tallest
    private func barHeight(for index: Int) -> CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 16
        let step = (maxH - minH) / CGFloat(barCount - 1)
        return minH + step * CGFloat(index)
    }

    /// Active bars use the level color; inactive bars are faint gray
    private func barColor(for index: Int) -> Color {
        index <= level ? activeColor : .gray.opacity(0.2)
    }

    /// Color based on signal level: green → yellow → orange → red
    private var activeColor: Color {
        switch level {
        case 3: return .green
        case 2: return .yellow
        case 1: return .orange
        default: return .red
        }
    }
}
