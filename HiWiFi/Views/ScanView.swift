import SwiftUI

/// Sidebar view — displays scanned WiFi networks with search filtering
struct ScanView: View {
    @EnvironmentObject var viewModel: WiFiCrackViewModel

    // MARK: - Body

    var body: some View {
        List(selection: $viewModel.selectedNetwork) {
            ForEach(viewModel.filteredNetworks) { network in
                WiFiRowView(network: network)
                    .tag(network)
                    .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("WiFi 网络")
        .searchable(
            text: $viewModel.searchText,
            placement: .sidebar,
            prompt: "搜索网络名称..."
        )
        .overlay(alignment: .top) {
            // Inline scanning indicator when refreshing an existing list
            if viewModel.isScanning && !viewModel.networks.isEmpty {
                scanningBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if viewModel.isScanning && viewModel.networks.isEmpty {
                scanningState
            } else if viewModel.filteredNetworks.isEmpty {
                emptyState
            }
        }
        .animation(.smooth, value: viewModel.isScanning)
        .animation(.smooth, value: viewModel.filteredNetworks)
    }

    // MARK: - Scanning Banner (overlay while list exists)

    private var scanningBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在扫描...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Scanning State (full screen)

    private var scanningState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .controlSize(.large)

            Text("正在扫描附近的网络...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("请稍候，这可能需要几秒钟")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating.speed(0.5))

            if viewModel.searchText.isEmpty {
                Text("暂无 WiFi 网络")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("点击右上角「扫描网络」按钮\n开始搜索周围的无线网络")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button {
                    viewModel.scanNetworks()
                } label: {
                    Label("立即扫描", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 8)
            } else {
                Text("没有匹配的网络")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("尝试修改搜索关键词")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
