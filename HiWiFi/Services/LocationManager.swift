// LocationManager.swift
// HiWiFi — Location Permission Manager for CoreWLAN SSID Access
// Copyright © 2026 CuoStudio. MIT License.

import Foundation
import CoreLocation

/// Coordinates requesting Location Services authorization to enable WiFi scanning.
final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        self.authorizationStatus = manager.authorizationStatus
    }

    /// Trigger the macOS Location Services request prompt
    func requestLocationPermission() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        // Stop updating immediately, we only need authorization, not active GPS tracking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.manager.stopUpdatingLocation()
        }
    }

    // MARK: - Delegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
