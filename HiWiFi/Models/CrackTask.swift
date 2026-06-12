// CrackTask.swift
// HiWiFi — Crack Task State Machine
// Copyright © 2026 CuoStudio. MIT License.

import Foundation

/// Tracks the state and progress of a WiFi password cracking task.
@Observable
final class CrackTask {
    var state: State = .idle
    var targetSSID: String = ""
    var currentPassword: String = ""
    var currentIndex: Int = 0
    var totalPasswords: Int = 0
    var startTime: Date?
    var endTime: Date?

    // MARK: - State Machine

    enum State: Equatable {
        case idle
        case loading       // Loading password dictionary
        case cracking      // Actively testing passwords
        case paused
        case success(password: String)
        case failed
        case cancelled
    }

    // MARK: - Computed

    /// Progress as 0.0–1.0
    var progress: Double {
        guard totalPasswords > 0 else { return 0 }
        return Double(currentIndex) / Double(totalPasswords)
    }

    /// Elapsed time since start
    var elapsed: TimeInterval {
        guard let start = startTime else { return 0 }
        return (endTime ?? Date()).timeIntervalSince(start)
    }

    /// Passwords tested per second
    var speed: Double {
        guard elapsed > 0 else { return 0 }
        return Double(currentIndex) / elapsed
    }

    /// Estimated time remaining (seconds)
    var eta: TimeInterval? {
        guard speed > 0, totalPasswords > currentIndex else { return nil }
        return Double(totalPasswords - currentIndex) / speed
    }

    // MARK: - Actions

    func start(ssid: String, total: Int) {
        state = .cracking
        targetSSID = ssid
        totalPasswords = total
        currentIndex = 0
        currentPassword = ""
        startTime = Date()
        endTime = nil
    }

    func pause() {
        guard state == .cracking else { return }
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .cracking
    }

    func succeed(password: String) {
        state = .success(password: password)
        endTime = Date()
    }

    func fail() {
        state = .failed
        endTime = Date()
    }

    func cancel() {
        state = .cancelled
        endTime = Date()
    }

    func reset() {
        state = .idle
        targetSSID = ""
        currentPassword = ""
        currentIndex = 0
        totalPasswords = 0
        startTime = nil
        endTime = nil
    }

    func advance(to password: String) {
        currentIndex += 1
        currentPassword = password
    }
}
