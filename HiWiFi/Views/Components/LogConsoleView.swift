import SwiftUI

/// Real-time log console — auto-scrolling, color-coded log entries
struct LogConsoleView: View {
    @EnvironmentObject var viewModel: WiFiCrackViewModel
    @State private var autoScroll = true

    /// Formatter for log timestamps
    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            consoleHeader
            Divider()
            consoleBody
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
    }

    // MARK: - Header

    private var consoleHeader: some View {
        HStack {
            Label("日志控制台", systemImage: "terminal.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Spacer()

            // Auto-scroll toggle
            Button {
                autoScroll.toggle()
            } label: {
                Image(systemName: autoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact")
                    .font(.caption)
                    .foregroundStyle(autoScroll ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(autoScroll ? "自动滚动：开" : "自动滚动：关")

            // Copy all
            Button {
                copyAllLogs()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("复制全部日志")
            .disabled(viewModel.logs.isEmpty)

            // Clear
            Button {
                withAnimation(.smooth) {
                    viewModel.logs.removeAll()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("清空日志")
            .disabled(viewModel.logs.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Console Body

    private var consoleBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.logs) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.logs.count) { _, _ in
                if autoScroll, let lastId = viewModel.logs.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .overlay {
            if viewModel.logs.isEmpty {
                emptyConsole
            }
        }
    }

    // MARK: - Log Row

    private func logRow(_ entry: WiFiCrackViewModel.LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Timestamp
            Text(Self.timestampFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Level indicator
            Circle()
                .fill(levelColor(entry.level))
                .frame(width: 6, height: 6)

            // Message
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(levelColor(entry.level))
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .padding(.vertical, 1)
    }

    // MARK: - Empty Console

    private var emptyConsole: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.title2)
                .foregroundStyle(.quaternary)

            Text("暂无日志")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func levelColor(_ level: WiFiCrackViewModel.LogLevel) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }

    private func copyAllLogs() {
        let text = viewModel.logs.map { entry in
            "[\(Self.timestampFormatter.string(from: entry.timestamp))] \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
