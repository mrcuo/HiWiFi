// CrackedResult.swift
// HiWiFi — Successfully Cracked WiFi Record
// Copyright © 2026 CuoStudio. MIT License.

import Foundation

/// A record of a successfully cracked WiFi password.
struct CrackedResult: Identifiable, Codable, Hashable {
    let id: UUID
    let ssid: String
    let password: String
    let security: String
    let date: Date

    init(ssid: String, password: String, security: String = "WPA2", date: Date = .now) {
        self.id = UUID()
        self.ssid = ssid
        self.password = password
        self.security = security
        self.date = date
    }
}

// MARK: - Local Persistence

extension CrackedResult {
    private static let fileName = "cracked_passwords.json"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("HiWiFi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// Load all saved results from disk
    static func loadAll() -> [CrackedResult] {
        guard let data = try? Data(contentsOf: fileURL),
              let results = try? JSONDecoder().decode([CrackedResult].self, from: data)
        else { return [] }
        return results.sorted { $0.date > $1.date }
    }

    /// Save results to disk
    static func saveAll(_ results: [CrackedResult]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(results) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Append a single result and persist
    static func append(_ result: CrackedResult) {
        var all = loadAll()
        // Avoid duplicates for same SSID
        all.removeAll { $0.ssid == result.ssid }
        all.insert(result, at: 0)
        saveAll(all)
    }

    /// Look up a previously cracked password for an SSID
    static func lookup(ssid: String) -> String? {
        loadAll().first { $0.ssid == ssid }?.password
    }

    /// Export as formatted text
    static func exportAsText(_ results: [CrackedResult]) -> String {
        results.enumerated().map { i, r in
            "(\(i + 1))  \(r.ssid)\t\(r.password)"
        }.joined(separator: "\n")
    }

    /// Export as JSON string
    static func exportAsJSON(_ results: [CrackedResult]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(results) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
