import SwiftUI

/// Results sheet — displays all cracked WiFi passwords in a table
struct ResultsView: View {
    @EnvironmentObject var viewModel: WiFiCrackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copiedId: UUID?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.crackedResults.isEmpty {
                emptyState
            } else {
                resultsTable
            }
        }
        .frame(width: 560, height: 440)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("破解记录")
                    .font(.title2.bold())
                Text("共 \(viewModel.crackedResults.count) 条记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !viewModel.crackedResults.isEmpty {
                Button {
                    viewModel.exportResults()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Results Table

    private var resultsTable: some View {
        Table(viewModel.crackedResults) {
            TableColumn("网络名称") { result in
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(result.ssid)
                        .fontWeight(.medium)
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("密码") { result in
                Text(result.password)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .width(min: 140, ideal: 180)

            TableColumn("日期") { result in
                Text(result.date, style: .date)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .width(min: 80, ideal: 100)

            TableColumn("操作") { result in
                Button {
                    viewModel.copyPassword(result.password)
                    copiedId = result.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedId == result.id { copiedId = nil }
                    }
                } label: {
                    Image(systemName: copiedId == result.id ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copiedId == result.id ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .animation(.smooth, value: copiedId)
                .help("复制密码")
            }
            .width(40)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)

            Text("暂无破解记录")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("成功破解的密码将显示在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
