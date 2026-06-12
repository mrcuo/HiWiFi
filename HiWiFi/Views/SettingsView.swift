import SwiftUI

/// Settings sheet — configure password source, timeouts, and advanced behavior
struct SettingsView: View {
    @EnvironmentObject var viewModel: WiFiCrackViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            formContent
            footer
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("设置")
                .font(.title2.bold())
            Spacer()
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
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            passwordSourceSection
            timingSection
            advancedSection
            aboutSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Password Source Section

    private var passwordSourceSection: some View {
        Section {
            Picker("密码来源", selection: $viewModel.passwordSource) {
                ForEach(PasswordGenerator.Source.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.passwordSource == .custom {
                HStack {
                    TextField("密码本路径", text: $viewModel.customPasswordPath)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("选择文件") {
                        selectFile()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Description for the selected source
            Group {
                switch viewModel.passwordSource {
                case .builtin:
                    Label("包含常见 WiFi 密码的内置密码本", systemImage: "book.closed.fill")
                case .custom:
                    Label("使用您自己的密码字典文件", systemImage: "doc.text.fill")
                case .generate:
                    Label("根据常见模式自动生成密码组合", systemImage: "wand.and.stars")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Label("密码本", systemImage: "key.fill")
        }
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("扫描超时")
                    Spacer()
                    Text(String(format: "%.0f 秒", viewModel.scanTimeout))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.scanTimeout, in: 1...15, step: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("连接超时")
                    Spacer()
                    Text(String(format: "%.0f 秒", viewModel.connectTimeout))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.connectTimeout, in: 3...30, step: 1)
            }
        } header: {
            Label("时间参数", systemImage: "timer")
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            Toggle(isOn: $viewModel.autoCrackAll) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动破解所有网络")
                    Text("扫描完成后自动依次尝试每个网络")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("高级选项", systemImage: "gearshape.2.fill")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("构建号")
                Spacer()
                Text("2024.06")
                    .foregroundStyle(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HiWiFi")
                        .font(.headline)
                    Text("仅供安全测试和学习用途")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "wifi.lock")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
        } header: {
            Label("关于", systemImage: "info.circle.fill")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - File Picker

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.title = "选择密码本文件"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.customPasswordPath = url.path
        }
    }
}
