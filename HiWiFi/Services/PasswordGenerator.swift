// PasswordGenerator.swift
// HiWiFi — Password Dictionary Loader & Generator
// Copyright © 2026 CuoStudio. MIT License.

import Foundation

/// Loads, generates, and manages password dictionaries for WiFi cracking.
struct PasswordGenerator {

    // MARK: - Password Source

    enum Source: String, CaseIterable, Codable {
        case builtin  = "内置密码本"
        case custom   = "自定义密码本"
        case generate = "自动生成"
    }

    // MARK: - Load Passwords

    /// Load passwords based on the selected source.
    static func load(source: Source, customPath: String = "") -> [String] {
        switch source {
        case .builtin:
            return loadBuiltin()
        case .custom:
            return loadFromFile(path: customPath)
        case .generate:
            return generateCommon()
        }
    }

    /// Load the built-in default password dictionary from bundle
    static func loadBuiltin() -> [String] {
        guard let url = Bundle.main.url(forResource: "passwords_default", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            // Fallback: return a minimal set of common passwords
            return Self.minimalPasswords
        }
        return parse(content)
    }

    /// Load passwords from a custom file path
    static func loadFromFile(path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(content)
    }

    /// Parse a newline-separated password file
    private static func parse(_ content: String) -> [String] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }  // Skip comments
    }

    // MARK: - Password Generation

    /// Generate common WiFi password patterns
    static func generateCommon() -> [String] {
        var passwords = [String]()

        // 1. Common fixed passwords
        passwords.append(contentsOf: minimalPasswords)

        // 2. 8-digit repeating numbers: 11111111, 22222222, ..., 99999999
        for d in 0...9 {
            passwords.append(String(repeating: String(d), count: 8))
        }

        // 3. Sequential patterns
        let seqs = [
            "12345678", "123456789", "1234567890", "87654321",
            "01234567", "98765432", "11223344", "12341234",
            "12121212", "13131313", "66668888", "88886666",
        ]
        passwords.append(contentsOf: seqs)

        // 4. Common Chinese weak passwords
        let chinese = [
            "woaini1314", "5201314520", "52013145201314",
            "1314520", "13145200", "iloveyou1", "asd123456",
            "woaini520", "woaini123", "abc123456", "a123456789",
            "aa123456", "qq123456", "zxcvbnm1", "asdfghjk",
        ]
        passwords.append(contentsOf: chinese)

        // 5. Year-based patterns (common birth years as WiFi passwords)
        for year in 1970...2010 {
            passwords.append("\(year)0101")
            passwords.append("\(year)1234")
            passwords.append("\(year)\(year)")
        }

        // 6. Common date patterns (MMDD repeated)
        for month in 1...12 {
            for day in [1, 10, 15, 20, 28] {
                let md = String(format: "%02d%02d", month, day)
                passwords.append("2000\(md)")
                passwords.append("1990\(md)")
                passwords.append("\(md)\(md)")
            }
        }

        // 7. Phone number prefixes (Chinese mobile)
        let prefixes = ["138", "139", "136", "137", "135", "158", "159",
                        "188", "186", "187", "182", "183", "151", "150"]
        for prefix in prefixes {
            // Add some common suffixes
            passwords.append("\(prefix)00000")
            passwords.append("\(prefix)12345")
            passwords.append("\(prefix)88888")
        }

        // Deduplicate and filter valid WiFi passwords (≥8 chars)
        return Array(Set(passwords))
            .filter { $0.count >= 8 }
            .sorted()
    }

    // MARK: - Minimal Fallback

    /// Minimal set of extremely common WiFi passwords
    static let minimalPasswords: [String] = [
        "12345678", "123456789", "1234567890", "88888888",
        "00000000", "11111111", "66666666", "12341234",
        "password", "password1", "admin123", "admin1234",
        "qwerty123", "iloveyou", "abcd1234", "1qaz2wsx",
        "a1234567", "abc12345", "test1234", "welcome1",
        "5201314520", "woaini1314", "1314520520", "asd123456",
        "zxcvbnm123", "asdfghjkl", "qwertyuiop", "1q2w3e4r",
    ]

    // MARK: - Priority Passwords

    /// Build a prioritized password list: previously cracked → source passwords
    static func buildPriorityList(for ssid: String, source: Source, customPath: String = "") -> [String] {
        var list = [String]()

        // Priority 1: Previously cracked password for this SSID
        if let cached = CrackedResult.lookup(ssid: ssid) {
            list.append(cached)
        }

        // Priority 2: Passwords from selected source
        let sourcePasswords = load(source: source, customPath: customPath)
        list.append(contentsOf: sourcePasswords)

        // Deduplicate while preserving order
        var seen = Set<String>()
        return list.filter { pwd in
            guard !seen.contains(pwd) else { return false }
            seen.insert(pwd)
            return true
        }
    }
}
