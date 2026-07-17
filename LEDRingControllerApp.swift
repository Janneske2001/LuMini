//
//  LEDRingControllerApp.swift
//  LuMini
//
//  Created by Jannes ‎ on 07/07/2026.
//

import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Helper: Rotated Menu Bar Icon
func rotatedMenuBarImage(size: CGFloat = 18) -> Image {
    let symbolName = "circle.hexagonpath.fill"
    guard let original = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return Image(systemName: symbolName)
    }
    
    let imageSize = original.size
    let rotated = NSImage(size: imageSize, flipped: false) { rect in
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -rect.midX, y: -rect.midY)
        original.draw(in: rect, from: NSRect(origin: .zero, size: imageSize), operation: .sourceOver, fraction: 1.0)
        return true
    }
    rotated.isTemplate = true
    return Image(nsImage: rotated)
}

// MARK: - App Delegate for managing activation policy
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as accessory (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct LEDRingControllerApp: App {
    @StateObject private var serialManager = RingController.shared.serialManager
    @StateObject private var updateChecker = UpdateChecker()
    @AppStorage("launchAtBoot") private var launchAtBoot: Bool = false
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(
                serialManager: serialManager,
                updateChecker: updateChecker,
                launchAtBoot: $launchAtBoot
            )
            .frame(width: 250)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
        } label: {
            rotatedMenuBarImage(size: 18)
        }
        .menuBarExtraStyle(.window)
        
        Window("LuMini", id: "main") {
            ContentView(updateChecker: updateChecker)
                .frame(minWidth: 600, minHeight: 500)
                .onAppear {
                    // When window appears, show dock icon
                    showDockIcon()
                }
                .onDisappear {
                    // When window disappears, hide dock icon
                    hideDockIcon()
                }
        }
        .handlesExternalEvents(matching: ["main"])
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
    
    // MARK: - Dock Icon Management
    private func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func hideDockIcon() {
        // The key: hide the app first, THEN change policy
        NSApp.hide(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Popover Content (Control Center style)
struct PopoverContentView: View {
    @ObservedObject var serialManager: SerialManager
    @ObservedObject var updateChecker: UpdateChecker
    @Binding var launchAtBoot: Bool
    
    @State private var brightnessDebounceTimer: Timer?
    @State private var rotationAngle: Double = 0
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    private let iconColors: [Color] = [
        Color(red: 1.0, green: 0.0, blue: 0.0),
        Color(red: 1.0, green: 0.5, blue: 0.0),
        Color(red: 1.0, green: 0.9, blue: 0.0),
        Color(red: 0.0, green: 0.9, blue: 0.0),
        Color(red: 10.0/255.0, green: 90.0/255.0, blue: 1.0),
        Color(red: 0.5, green: 20.0/255.0, blue: 1.0)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // MARK: Header – Logo + Status
            HStack {
                RingView(colors: iconColors, ledCount: 6)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                Text("LuMini")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(serialManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(serialManager.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 2)
            .padding(.trailing, 10)
            
            // MARK: Toggles
            HStack(spacing: 16) {
                NativeToggle(
                    isOn: Binding(
                        get: { serialManager.isPoweredOn },
                        set: { newValue in
                            serialManager.sendCommand(newValue ? "ON" : "OFF")
                            serialManager.isPoweredOn = newValue
                        }
                    ),
                    icon: "power",
                    label: "Power"
                )
                .help("Turn the ring on or off")
                
                NativeToggle(
                    isOn: $launchAtBoot,
                    icon: "bolt",
                    label: "Login"
                )
                .help("Launch at login")
                .onChange(of: launchAtBoot) { _, newValue in
                    setLaunchAtBoot(enabled: newValue)
                }
                
                NativeToggle(
                    isOn: $serialManager.autoSleepWake,
                    icon: "moon",
                    label: "Sleep"
                )
                .help("Auto sleep/wake")
            }
            .padding(.vertical, 2)
            
            Divider()
            
            // MARK: Brightness Slider
            HStack(spacing: 6) {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(serialManager.brightness) },
                        set: { newValue in
                            serialManager.brightness = Int(newValue)
                            brightnessDebounceTimer?.invalidate()
                            brightnessDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                serialManager.sendCommand("SET BRIGHT=\(Int(newValue))")
                            }
                        }
                    ),
                    in: 0...255
                )
                .frame(width: 150)
                .help("Brightness")
                Image(systemName: "sun.max")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(serialManager.brightness)")
                    .font(.caption)
                    .frame(minWidth: 25, alignment: .trailing)
            }
            
            Divider()
            
            // MARK: Action Buttons
            HStack(spacing: 10) {
                // Gear – Open Configuration
                ActionButton(
                    icon: "gearshape.circle",
                    action: {
                        // CRITICAL: Show dock icon BEFORE opening the window
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        
                        openWindow(id: "main")
                        
                        // Force window to front
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let window = NSApplication.shared.windows.first(where: { $0.title == "LuMini" }) {
                                window.makeKeyAndOrderFront(nil)
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                        dismiss()
                    }
                )
                .help("Open Configuration")
                
                // Update – Check for Updates
                ActionButton(
                    icon: "arrow.triangle.2.circlepath.circle",
                    action: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            rotationAngle += 360
                        }
                        
                        updateChecker.checkForUpdatesManually { hasUpdate, version in
                            let alert = NSAlert()
                            alert.alertStyle = .informational
                            
                            if hasUpdate {
                                alert.messageText = "Update Available"
                                alert.informativeText = "A new version (\(version ?? "unknown")) is available. Download it now?"
                                alert.addButton(withTitle: "Download")
                                alert.addButton(withTitle: "Later")
                                let response = alert.runModal()
                                if response == .alertFirstButtonReturn {
                                    NSWorkspace.shared.open(URL(string: "https://github.com/Janneske2001/LuMini/releases/latest")!)
                                }
                            } else {
                                alert.messageText = "No Updates"
                                alert.informativeText = "You're running the latest version of LuMini."
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        }
                    }
                )
                .rotationEffect(.degrees(rotationAngle))
                .help("Check for Updates")
                
                Spacer()
                    .frame(width: 10)
                
                // X – Quit
                ActionButton(
                    icon: "xmark.circle",
                    action: {
                        let alert = NSAlert()
                        alert.alertStyle = .warning
                        alert.messageText = "Quit LuMini?"
                        alert.informativeText = "Shortcuts and automations will stop working if the app is not running in the background."
                        alert.addButton(withTitle: "Quit")
                        alert.addButton(withTitle: "Cancel")
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                )
                .help("Quit LuMini")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 5)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
    
    private func setLaunchAtBoot(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at boot: \(error)")
                DispatchQueue.main.async {
                    launchAtBoot = !enabled
                }
            }
        } else {
            print("Launch at boot requires macOS 13+")
        }
    }
}

// MARK: - Native Toggle
struct NativeToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.white : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(isOn ? 0.05 : 0.1), radius: 2, x: 0, y: 1)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isOn ? .black : .white)
                }
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}
