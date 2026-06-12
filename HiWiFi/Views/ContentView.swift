import SwiftUI

/// Main application window — three-column NavigationSplitView layout
/// Sidebar: WiFi network list | Detail: Crack controls | Inspector: Log console
struct ContentView: View {
    @StateObject private var viewModel = WiFiCrackViewModel()
    @State private var showSettings = false
    @State private var showResults = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // — Sidebar: WiFi network list
            ScanView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 280, max: 280)
        } detail: {
            HStack(spacing: 0) {
                // — Detail: Crack progress & controls
                CrackProgressView()
                    .frame(minWidth: 440, maxWidth: .infinity)

                Divider()

                // — Inspector: Live log console
                LogConsoleView()
                    .frame(width: 320)
            }
        }
        .environmentObject(viewModel)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showResults) {
            ResultsView()
                .environmentObject(viewModel)
        }
        .alert("网络断开警告", isPresented: $viewModel.showSafetyWarning) {
            Button("取消", role: .cancel) { }
            Button("继续测试", role: .destructive) {
                if let network = viewModel.selectedNetwork {
                    viewModel.startCracking(network: network)
                }
            }
        } message: {
            Text("密码枚举测试需要独占无线网卡，这将导致您当前的网络暂时断开。\n\n测试结束或手动停止后，系统将尝试自动恢复原有的网络连接。\n\n确定要继续吗？")
        }
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .frame(minWidth: 1040, minHeight: 600)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Scan button
            Button {
                viewModel.scanNetworks()
            } label: {
                Label("扫描网络", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(viewModel.isScanning)
            .help("扫描附近的 WiFi 网络")

            // Auto-crack all toggle
            Button {
                viewModel.autoCrackAll.toggle()
            } label: {
                Label(
                    "自动破解",
                    systemImage: viewModel.autoCrackAll
                        ? "bolt.shield.fill"
                        : "bolt.shield"
                )
            }
            .help("自动尝试破解所有网络")

            Divider()

            // Results
            Button {
                showResults = true
            } label: {
                Label("破解记录", systemImage: "checkmark.seal.fill")
            }
            .help("查看已破解的密码")

            // Settings
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .help("打开设置面板")
        }

        ToolbarItem(placement: .navigation) {
            // Scanning indicator in leading position
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
}
