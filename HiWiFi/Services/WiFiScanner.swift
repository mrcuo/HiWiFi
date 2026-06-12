// WiFiScanner.swift
// HiWiFi — WiFi Network Scanner using CoreWLAN
// Copyright © 2026 CuoStudio. MIT License.

import Foundation
import CoreWLAN

/// Scans for nearby WiFi networks using the CoreWLAN framework.
actor WiFiScanner {
    private let client = CWWiFiClient.shared()

    /// The default WiFi interface (usually en0)
    var interface: CWInterface? {
        client.interface()
    }

    /// Current interface name
    var interfaceName: String {
        interface?.interfaceName ?? "en0"
    }

    /// Check if WiFi hardware is powered on
    var isPoweredOn: Bool {
        interface?.powerOn() ?? false
    }

    /// Currently connected SSID (nil if not connected)
    var currentSSID: String? {
        interface?.ssid()
    }

    // MARK: - Scanning

    /// Scan for all visible WiFi networks.
    /// - Parameter timeout: Not directly used by CoreWLAN, reserved for future use.
    /// - Returns: Array of discovered WiFi networks, sorted by signal strength.
    func scan() throws -> [WiFiNetwork] {
        guard let iface = interface else {
            throw WiFiScanError.noInterface
        }
        guard iface.powerOn() else {
            throw WiFiScanError.wifiDisabled
        }

        let cwNetworks: Set<CWNetwork>
        do {
            cwNetworks = try iface.scanForNetworks(withName: nil)
        } catch {
            throw WiFiScanError.scanFailed(error.localizedDescription)
        }

        // Cache the scanned CWNetwork objects before converting
        for cw in cwNetworks {
            if let ssid = cw.ssid {
                CWNetworkCache.shared.set(cw, for: ssid)
            }
        }

        let networks = cwNetworks
            .compactMap { WiFiNetwork.from($0) }
            .sorted { $0.rssi > $1.rssi }  // Strongest first

        // Deduplicate by SSID, keeping strongest signal
        var seen = Set<String>()
        return networks.filter { n in
            guard !seen.contains(n.ssid) else { return false }
            seen.insert(n.ssid)
            return true
        }
    }

    // MARK: - Errors

    enum WiFiScanError: LocalizedError {
        case noInterface
        case wifiDisabled
        case scanFailed(String)

        var errorDescription: String? {
            switch self {
            case .noInterface:
                return "未找到无线网卡"
            case .wifiDisabled:
                return "WiFi 未开启，请先开启 WiFi"
            case .scanFailed(let msg):
                return "扫描失败: \(msg)"
            }
        }
    }
}
