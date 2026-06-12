// WiFiConnector.swift
// HiWiFi — WiFi Connection Tester
// Copyright © 2026 CuoStudio. MIT License.

import Foundation
import CoreWLAN
import SystemConfiguration

/// Attempts to connect to a WiFi network with a given password.
/// Uses CoreWLAN as primary method, falls back to `networksetup` command.
actor WiFiConnector {
    private let client = CWWiFiClient.shared()

    /// Default connection timeout in seconds
    private(set) var connectTimeout: TimeInterval = 8.0

    // Cache to avoid repeated network scanning
    private var cachedTargetNetwork: CWNetwork?
    private var cachedSSID: String?
    private var useNetworksetupFallback = false

    /// Set connection timeout
    func setConnectTimeout(_ timeout: TimeInterval) {
        self.connectTimeout = timeout
    }

    /// Reset caching and fallback states for a new test run
    func resetConnectionState() {
        self.cachedTargetNetwork = nil
        self.cachedSSID = nil
        self.useNetworksetupFallback = false
    }

    private func getTargetNetwork(ssid: String) throws -> CWNetwork {
        if let cached = cachedTargetNetwork, cachedSSID == ssid {
            return cached
        }
        if let cached = CWNetworkCache.shared.get(for: ssid) {
            cachedTargetNetwork = cached
            cachedSSID = ssid
            return cached
        }
        guard let iface = client.interface() else {
            throw ConnectionError.noInterface
        }
        let networks = try iface.scanForNetworks(withName: ssid)
        guard let target = networks.first(where: { $0.ssid == ssid }) else {
            throw ConnectionError.networkNotFound(ssid)
        }
        cachedTargetNetwork = target
        cachedSSID = ssid
        return target
    }

    // MARK: - Connection Testing

    /// Test whether a password can successfully connect to a WiFi network.
    /// - Parameters:
    ///   - ssid: Target network SSID
    ///   - password: Password to test
    ///   - security: Security type of the network
    /// - Returns: `true` if connection succeeded
    func testPassword(ssid: String, password: String, security: WiFiNetwork.SecurityType) async -> Bool {
        if useNetworksetupFallback {
            return await testViaNetworksetup(ssid: ssid, password: password)
        }

        do {
            let target = try getTargetNetwork(ssid: ssid)
            let result = try await testViaCorewlan(target: target, ssid: ssid, password: password)
            return result
        } catch {
            let nsError = error as NSError
            // Only switch to networksetup fallback permanently on persistent setup/permission errors
            if error is ConnectionError || (nsError.domain == CWErrorDomain && nsError.code == -3901) {
                useNetworksetupFallback = true
            }
            return await testViaNetworksetup(ssid: ssid, password: password)
        }
    }

    // MARK: - CoreWLAN Method

    /// Attempt connection via CoreWLAN CWInterface.associate
    private func testViaCorewlan(target: CWNetwork, ssid: String, password: String) async throws -> Bool {
        guard let iface = client.interface() else {
            throw ConnectionError.noInterface
        }

        do {
            try iface.associate(to: target, password: password)
            // Wait briefly for interface state to settle
            try await Task.sleep(for: .milliseconds(500))

            if iface.ssid() == ssid {
                return true
            }
            return false
        } catch {
            let nsError = error as NSError
            let domain = nsError.domain
            if domain == CWErrorDomain || domain == "com.apple.wifi.apple80211API.error" {
                let code = nsError.code
                // Common wrong password / association failure error codes:
                // -3905: Association failed
                // -3906: Authentication failed
                // -3924: Security mode mismatch or other wrong configuration
                // -3925: kCWAssocFailedErr (Association failed - wrong password/timeout)
                // -3926: kCWAuthFailedErr (Authentication failed - wrong password)
                if code == -3905 || code == -3906 || code == -3924 || code == -3925 || code == -3926 {
                    return false
                }
            }
            // Other errors (e.g. no permission, device busy) should bubble up to trigger networksetup fallback
            throw error
        }
    }

    // MARK: - networksetup Fallback

    /// Attempt connection via `networksetup` command line tool
    private func testViaNetworksetup(ssid: String, password: String) async -> Bool {
        let interfaceName = client.interface()?.interfaceName ?? "en0"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-setairportnetwork", interfaceName, ssid, password]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()

            // Wait for process with timeout
            let deadline = Date().addingTimeInterval(connectTimeout)
            while process.isRunning && Date() < deadline {
                try await Task.sleep(for: .milliseconds(200))
            }

            if process.isRunning {
                process.terminate()
                return false
            }

            // Check output for success
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // networksetup returns empty string on success, error message on failure
            if output.isEmpty || !output.lowercased().contains("error") {
                try await Task.sleep(for: .seconds(1))
                return await verifyConnection(timeout: 3)
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Connection Verification

    /// Verify that we're actually connected to a network
    private func verifyConnection(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let currentSSID = client.interface()?.ssid(), !currentSSID.isEmpty {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    /// Disconnect from current network
    func disconnect() {
        client.interface()?.disassociate()
    }

    // MARK: - Errors

    enum ConnectionError: LocalizedError {
        case noInterface
        case networkNotFound(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .noInterface:     return "未找到无线网卡"
            case .networkNotFound(let s): return "未找到网络: \(s)"
            case .timeout:         return "连接超时"
            }
        }
    }
}
