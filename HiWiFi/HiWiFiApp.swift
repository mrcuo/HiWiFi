// HiWiFiApp.swift
// HiWiFi — WiFi借一下
// A macOS native WiFi password testing tool
// Copyright © 2026 CuoStudio. MIT License.

import SwiftUI

@main
struct HiWiFiApp: App {
    @StateObject private var viewModel = WiFiCrackViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1040, minHeight: 600)
                .onAppear {
                    // Configure window appearance and enforce size limits strictly
                    NSWindow.allowsAutomaticWindowTabbing = false
                    if let window = NSApplication.shared.windows.first(where: { $0.delegate != nil }) {
                        window.minSize = NSSize(width: 1040, height: 600)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 700)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {}

            // Custom commands
            CommandMenu("操作") {
                Button("扫描 WiFi") {
                    viewModel.scanNetworks()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isScanning)

                Divider()

                Button("开始破解") {
                    viewModel.startCracking()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!viewModel.canStartCrack)

                Button(viewModel.isPaused ? "继续" : "暂停") {
                    viewModel.isPaused ? viewModel.resumeCracking() : viewModel.pauseCracking()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!viewModel.isCracking)

                Button("停止") {
                    viewModel.stopCracking()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!viewModel.isCracking)

                Divider()

                Button("导出结果...") {
                    viewModel.exportResults()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("清除日志") {
                    viewModel.clearLogs()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
