// WiFiNetwork.swift
// HiWiFi — WiFi Network Data Model
// Copyright © 2026 CuoStudio. MIT License.

import Foundation
import CoreWLAN

/// Represents a discovered WiFi network with scan metadata and crack status.
struct WiFiNetwork: Identifiable, Hashable {
    let id = UUID()
    let ssid: String
    let bssid: String
    let rssi: Int           // Signal strength in dBm
    let channel: Int
    let security: SecurityType
    var status: CrackStatus = .idle
    var crackedPassword: String?

    // MARK: - Security Type

    enum SecurityType: String, CaseIterable, Codable {
        case wpa2    = "WPA2"
        case wpa3    = "WPA3"
        case wep     = "WEP"
        case open    = "Open"
        case unknown = "Unknown"

        /// Map CoreWLAN security mode to our enum
        static func from(_ cwSecurity: CWSecurity) -> SecurityType {
            switch cwSecurity {
            case .wpaPersonal, .wpaEnterprise,
                 .wpa2Personal, .wpa2Enterprise,
                 .dynamicWEP:
                return .wpa2
            case .wpa3Personal, .wpa3Enterprise,
                 .wpa3Transition:
                return .wpa3
            case .WEP:
                return .wep
            case .none:
                return .open
            default:
                return .unknown
            }
        }

        /// Determine security type from a CWNetwork's supported features
        static func from(_ cwNetwork: CWNetwork) -> SecurityType {
            if cwNetwork.supportsSecurity(.wpa3Personal) ||
                cwNetwork.supportsSecurity(.wpa3Transition) ||
                cwNetwork.supportsSecurity(.wpa3Enterprise) {
                return .wpa3
            } else if cwNetwork.supportsSecurity(.wpa2Personal) ||
                      cwNetwork.supportsSecurity(.wpa2Enterprise) {
                return .wpa2
            } else if cwNetwork.supportsSecurity(.wpaPersonal) ||
                      cwNetwork.supportsSecurity(.wpaPersonalMixed) ||
                      cwNetwork.supportsSecurity(.wpaEnterprise) ||
                      cwNetwork.supportsSecurity(.wpaEnterpriseMixed) {
                return .wpa2
            } else if cwNetwork.supportsSecurity(.WEP) ||
                      cwNetwork.supportsSecurity(.dynamicWEP) {
                return .wep
            } else if cwNetwork.supportsSecurity(.none) {
                return .open
            } else {
                return .unknown
            }
        }
    }

    // MARK: - Crack Status

    enum CrackStatus: String, Codable {
        case idle     = "idle"
        case cracking = "cracking"
        case paused   = "paused"
        case success  = "success"
        case failed   = "failed"
    }

    // MARK: - Computed Properties

    /// Signal level 0–3 for UI display
    var signalLevel: Int {
        switch rssi {
        case -50...0:    return 3   // Excellent
        case -65...(-51): return 2  // Good
        case -80...(-66): return 1  // Fair
        default:          return 0  // Weak
        }
    }

    /// Human-readable signal description
    var signalDescription: String {
        switch signalLevel {
        case 3:  return "极好"
        case 2:  return "良好"
        case 1:  return "一般"
        default: return "较弱"
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(bssid)
    }

    static func == (lhs: WiFiNetwork, rhs: WiFiNetwork) -> Bool {
        lhs.bssid == rhs.bssid
    }
}

// MARK: - Factory

extension WiFiNetwork {
    /// Create from a CoreWLAN scan result
    static func from(_ cwNetwork: CWNetwork) -> WiFiNetwork? {
        guard let ssid = cwNetwork.ssid, !ssid.isEmpty else { return nil }
        return WiFiNetwork(
            ssid: ssid,
            bssid: cwNetwork.bssid ?? "Unknown",
            rssi: cwNetwork.rssiValue,
            channel: cwNetwork.wlanChannel?.channelNumber ?? 0,
            security: SecurityType.from(cwNetwork)
        )
    }
}
