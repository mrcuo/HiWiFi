import SwiftUI

/// Detail panel — shows selected WiFi info, progress ring, live stats, and action controls
struct CrackProgressView: View {
    @EnvironmentObject var viewModel: WiFiCrackViewModel
    @State private var showCopiedToast = false

    // MARK: - Body

    var body: some View {
        Group {
            if let network = viewModel.selectedNetwork {
                selectedContent(network)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Placeholder (no selection)

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.router")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
                .symbolEffect(.breathe.plain, options: .repeating.speed(0.3))

            Text("选择一个 WiFi 网络")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("从左侧列表中选择要测试的网络")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Selected Network Content

    private func selectedContent(_ network: WiFiNetwork) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                networkInfoCard(network)

                switch network.status {
                case .success:
                    successView(network)
                case .failed:
                    failedView
                default:
                    progressSection(network)
                    actionButtons(network)
                }
            }
            .padding(32)
        }
    }

    // MARK: - Network Info Card

    private func networkInfoCard(_ network: WiFiNetwork) -> some View {
        HStack(spacing: 16) {
            SignalIndicator(level: network.signalLevel)
                .frame(width: 32, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(network.ssid)
                    .font(.title2.bold())

                HStack(spacing: 10) {
                    StatusBadge(text: network.security.rawValue, style: securityStyle(network.security))
                    Label("频道 \(network.channel)", systemImage: "antenna.radiowaves.left.and.right.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(network.rssi) dBm", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            statusDot(network.status)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Progress Section

    private func progressSection(_ network: WiFiNetwork) -> some View {
        VStack(spacing: 24) {
            // Circular progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 12)
                    .frame(width: 160, height: 160)

                // Progress arc
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .cyan, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.4), value: viewModel.progress)

                // Center percentage
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(viewModel.progress * 100))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.smooth, value: Int(viewModel.progress * 100))

                    Text("%")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
            }

            // Current password being tested
            if viewModel.isCracking {
                VStack(spacing: 6) {
                    Text("正在测试")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(viewModel.currentPassword)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.smooth, value: viewModel.currentPassword)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Stats row
            statsRow
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 24) {
            statItem(
                icon: "number.circle.fill",
                label: "已尝试",
                value: "\(viewModel.currentIndex)/\(viewModel.totalPasswords)"
            )
            statItem(
                icon: "gauge.open.with.lines.needle.33percent",
                label: "速度",
                value: formattedSpeed
            )
            statItem(
                icon: "clock.fill",
                label: "已用时",
                value: formattedElapsed
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .contentTransition(.numericText())
                .animation(.smooth, value: value)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Action Buttons

    private func actionButtons(_ network: WiFiNetwork) -> some View {
        HStack(spacing: 16) {
            if viewModel.isCracking {
                // Pause / Resume
                Button {
                    if viewModel.isPaused {
                        viewModel.resumeCracking()
                    } else {
                        viewModel.pauseCracking()
                    }
                } label: {
                    Label(
                        viewModel.isPaused ? "继续" : "暂停",
                        systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isPaused ? .green : .orange)
                .controlSize(.large)

                // Stop
                Button(role: .destructive) {
                    viewModel.stopCracking()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                // Start
                Button {
                    viewModel.startCracking()
                } label: {
                    Label("开始破解", systemImage: "lock.open.rotation")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(network.security == .open)
            }
        }
        .animation(.smooth, value: viewModel.isCracking)
        .animation(.smooth, value: viewModel.isPaused)
    }

    // MARK: - Success View

    private func successView(_ network: WiFiNetwork) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text("破解成功！")
                .font(.title.bold())
                .foregroundStyle(.green)

            if let password = network.crackedPassword {
                VStack(spacing: 8) {
                    Text("密码")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Text(password)
                            .font(.system(.title2, design: .monospaced).bold())
                            .textSelection(.enabled)

                        Button {
                            viewModel.copyPassword(password)
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        } label: {
                            Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .tint(showCopiedToast ? .green : .accentColor)
                        .animation(.smooth, value: showCopiedToast)
                    }
                    .padding(16)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text("未找到密码")
                .font(.title.bold())
                .foregroundStyle(.red)

            Text("密码本中的所有密码均已尝试完毕")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.startCracking()
            } label: {
                Label("重新尝试", systemImage: "arrow.clockwise")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Helpers

    private var formattedElapsed: String {
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedSpeed: String {
        let speed = viewModel.speed
        if speed == 0 {
            return "0 个/秒"
        } else if speed < 1.0 {
            return String(format: "%.1f 个/分", speed * 60)
        } else {
            return String(format: "%.1f 个/秒", speed)
        }
    }

    private func statusDot(_ status: WiFiNetwork.CrackStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
            .shadow(color: statusColor(status).opacity(0.5), radius: 4)
            .animation(.smooth, value: status)
    }

    private func statusColor(_ status: WiFiNetwork.CrackStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .cracking: return .blue
        case .paused: return .orange
        case .success: return .green
        case .failed: return .red
        }
    }

    private func securityStyle(_ security: WiFiNetwork.SecurityType) -> StatusBadge.Style {
        switch security {
        case .wpa3: return .error
        case .wpa2: return .warning
        case .wep: return .success
        case .open: return .success
        case .unknown: return .default
        }
    }
}
