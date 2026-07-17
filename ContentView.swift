//
//  ContentView.swift
//  LuMini
//
//  Created by Jannes ‎ on 07/07/2026.
//

import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers
import ServiceManagement

// MARK: - Codable RGB
struct CodableRGB: Codable {
    var r: Int
    var g: Int
    var b: Int
}

// MARK: - Saved Settings
struct SavedSettings: Codable {
    // (unchanged – same as before)
    var effect: String
    var direction: String
    var mainColor: CodableRGB
    var bgColor: CodableRGB
    var speed: Double
    var brightness: Int
    var scale: Double
    var gradientColors: [CodableRGB]
    
    init(serialManager: SerialManager, gradientStops: [GradientStop]) {
        self.effect = serialManager.effect
        self.direction = serialManager.direction
        let main = serialManager.mainColor.toRGB()
        self.mainColor = CodableRGB(r: main.r, g: main.g, b: main.b)
        let bg = serialManager.bgColor.toRGB()
        self.bgColor = CodableRGB(r: bg.r, g: bg.g, b: bg.b)
        self.speed = serialManager.speed
        self.brightness = serialManager.brightness
        self.scale = serialManager.scale
        let sorted = gradientStops.sorted { $0.position < $1.position }
        self.gradientColors = sorted.map { stop in
            let rgb = stop.color.toRGB()
            return CodableRGB(r: rgb.r, g: rgb.g, b: rgb.b)
        }
    }
    
    func apply(to serialManager: SerialManager, gradientStops: inout [GradientStop]) {
        serialManager.effect = effect
        serialManager.direction = direction
        serialManager.mainColor = Color(red: Double(mainColor.r)/255,
                                        green: Double(mainColor.g)/255,
                                        blue: Double(mainColor.b)/255)
        serialManager.bgColor = Color(red: Double(bgColor.r)/255,
                                      green: Double(bgColor.g)/255,
                                      blue: Double(bgColor.b)/255)
        serialManager.speed = speed
        serialManager.brightness = brightness
        serialManager.scale = scale
        
        let count = gradientColors.count
        if count >= 2 {
            let newStops = gradientColors.enumerated().map { index, rgb in
                let position = CGFloat(index) / CGFloat(count - 1)
                return GradientStop(position: position,
                                    color: Color(red: Double(rgb.r)/255,
                                                 green: Double(rgb.g)/255,
                                                 blue: Double(rgb.b)/255))
            }
            gradientStops = newStops
            serialManager.gradientColors = newStops.map { $0.color }
        }
    }
}

// MARK: - Preset Manager
struct PresetManager {
    static let fileExtension = "rgb"
    static let directoryName = "LED Ring Presets"
    
    static func save(settings: SavedSettings, to url: URL) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: url)
    }
    
    static func load(from url: URL) throws -> SavedSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SavedSettings.self, from: data)
    }
}

// MARK: - Gradient Stop Model
struct GradientStop: Identifiable {
    let id = UUID()
    var position: CGFloat
    var color: Color
}

// MARK: - NSColorWell Wrapper
class WellHolder: ObservableObject {
    weak var well: NSColorWell?
    func open() { well?.performClick(nil) }
    func close() { well?.deactivate() }
}

struct NativeColorWellWithHolder: NSViewRepresentable {
    @Binding var color: Color
    weak var wellHolder: WellHolder?
    var onColorChange: (Color) -> Void
    
    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.supportsAlpha = false
        well.color = NSColor(color)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        wellHolder?.well = well
        return well
    }
    
    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = NSColor(color)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color, onColorChange: onColorChange)
    }
    
    class Coordinator: NSObject {
        var color: Binding<Color>
        var onColorChange: (Color) -> Void
        
        init(color: Binding<Color>, onColorChange: @escaping (Color) -> Void) {
            self.color = color
            self.onColorChange = onColorChange
        }
        
        @objc func colorChanged(_ sender: NSColorWell) {
            let newColor = Color(sender.color)
            color.wrappedValue = newColor
            onColorChange(newColor)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Binding var updateAvailable: Bool
    @Binding var latestVersion: String
    @Binding var showingAboutPopover: Bool
    @Binding var autoCheckForUpdates: Bool
    @ObservedObject var updateChecker: UpdateChecker

    @State private var showingManualAlert = false
    @State private var manualAlertMessage = ""
    @State private var manualAlertHasUpdate = false
    @State private var manualUpdateVersion = ""
    @State private var checking = false

    var body: some View {
        VStack(spacing: 16) {
            Image("profile")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            
            Text("LuMini")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Built by Janneske2001")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Button {
                NSWorkspace.shared.open(URL(string: "https://twitter.com/LuMini_Mods")!)
            } label: {
                Label("Twitter", systemImage: "bird")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                NSWorkspace.shared.open(URL(string: "https://paypal.me/janneske2001")!)
            } label: {
                Label("Donate", systemImage: "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/Janneske2001/LuMini")!)
            } label: {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Divider()
            
            if updateAvailable {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("New version \(latestVersion) available!")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                
                HStack {
                    Button("Download") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/Janneske2001/LuMini/releases/latest")!)
                        showingAboutPopover = false
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Dismiss") {
                        updateAvailable = false
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
            }
            
            Toggle("Check for Updates Automatically", isOn: $autoCheckForUpdates)
                .toggleStyle(.checkbox)
                .font(.caption)
            
            Button {
                checking = true
                updateChecker.checkForUpdatesManually { hasUpdate, version in
                    checking = false
                    if hasUpdate {
                        manualAlertHasUpdate = true
                        manualUpdateVersion = version ?? "unknown"
                        manualAlertMessage = "A new version (\(version ?? "unknown")) is available. Download it now?"
                    } else {
                        manualAlertHasUpdate = false
                        manualAlertMessage = "You're running the latest version of LuMini."
                    }
                    showingManualAlert = true
                }
            } label: {
                if checking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Check Now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(checking)
        }
        .padding(20)
        .frame(width: 260)
        .alert(isPresented: $showingManualAlert) {
            if manualAlertHasUpdate {
                return Alert(
                    title: Text("Update Available"),
                    message: Text(manualAlertMessage),
                    primaryButton: .default(Text("Download")) {
                        NSWorkspace.shared.open(URL(string: "https://github.com/Janneske2001/LuMini/releases/latest")!)
                    },
                    secondaryButton: .cancel(Text("Later"))
                )
            } else {
                return Alert(
                    title: Text("No Updates"),
                    message: Text(manualAlertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var serialManager = RingController.shared.serialManager
    @ObservedObject var updateChecker: UpdateChecker
    
    @State private var gradientStops: [GradientStop] = [
        GradientStop(position: 0.0, color: Color(red: 1, green: 0, blue: 0)),
        GradientStop(position: 1.0, color: Color(red: 0, green: 0, blue: 1))
    ]
    
    @State private var previewTimestamp = Date()
    private let previewTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    private let gradientSpeedMultiplier: Double = 3.1
    private let rainbowSpeedMultiplier: Double = 1.0
    private let breatheSpeedMultiplier: Double = 2.666
    private let chaseSpeedMultiplier: Double = 1.0
    private let knightSpeedMultiplier: Double = 1.0
    
    @State private var colorDebounceTimer: Timer?
    @State private var bgDebounceTimer: Timer?
    @State private var speedDebounceTimer: Timer?
    @State private var brightnessDebounceTimer: Timer?
    @State private var scaleDebounceTimer: Timer?
    @State private var gradientUpdateTimer: Timer?
    @State private var showResetConfirmation = false
    
    @State private var showingSaveAlert = false
    @State private var showingLoadAlert = false
    @State private var errorAlertMessage: String? = nil
    @State private var showingErrorAlert = false
    
    @State private var savedFileURL: URL? = nil
    @State private var showingSaveConfirmation = false
    
    @AppStorage("launchAtBoot") private var launchAtBoot: Bool = false
    @AppStorage("lastUpdateCheckDate") private var lastUpdateCheckDate: Date?
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates: Bool = true
    
    @State private var showingAboutPopover = false
    
    private let maxGradientStops = 10
    
    private var iconColors: [Color] {
        [
            Color(red: 1.0, green: 0.0, blue: 0.0),
            Color(red: 1.0, green: 0.5, blue: 0.0),
            Color(red: 1.0, green: 0.9, blue: 0.0),
            Color(red: 0.0, green: 0.9, blue: 0.0),
            Color(red: 10.0/255.0, green: 90.0/255.0, blue: 1.0),
            Color(red: 0.5, green: 20.0/255.0, blue: 1.0)
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: Header
                    HStack {
                        // Use the new HeaderRingView with bigger dots
                        HeaderRingView(colors: iconColors, ledCount: 6)
                            .frame(width: 28, height: 28)
                            .padding(.trailing, 4)
                        Text("LuMini by Janneske2001")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(serialManager.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(serialManager.isConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button("Refresh") { serialManager.refreshPorts() }
                            .buttonStyle(.bordered)
                            .help("Rescan for connected serial devices")
                        Toggle("", isOn: $serialManager.isPoweredOn)
                            .toggleStyle(.switch)
                            .onChange(of: serialManager.isPoweredOn) { _, newValue in
                                serialManager.sendCommand(newValue ? "ON" : "OFF")
                            }
                            .help("Turn the ring on or off")
                    }
                    .padding(.bottom, 5)
                    
                    Divider()
                    
                    // MARK: Effect + Preview Ring
                    HStack(alignment: .center, spacing: 12) {
                        GroupBox(label: Label("Effect", systemImage: "sparkles")
                            .font(.headline)
                            .fontWeight(.semibold)
                        ) {
                            Picker("", selection: $serialManager.effect) {
                                Text("Static").tag("STATIC")
                                Text("Breathe").tag("BREATHE")
                                Text("Chase").tag("CHASE")
                                Text("Knight").tag("KNIGHT")
                                Text("Gradient").tag("GRADIENT")
                                Text("Rainbow").tag("RAINBOW")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: serialManager.effect) { _, newEffect in
                                if newEffect == "GRADIENT" {
                                    sendGradientToRing()
                                } else {
                                    serialManager.sendCommand("SET EFFECT=\(newEffect)")
                                }
                            }
                            .help("Select the LED effect")
                        }
                        Spacer()
                        // Preview ring uses the original RingView (unchanged)
                        RingView(colors: computePreviewColors(), ledCount: 24)
                            .rotationEffect(Angle(degrees: 7.5))
                            .drawingGroup()
                            .frame(width: 90, height: 90)
                            .padding(4)
                            .padding(.trailing, 4)
                    }
                    
                    // MARK: Colors
                    let showColors = serialManager.effect != "OFF" && serialManager.effect != "GRADIENT" && serialManager.effect != "RAINBOW"
                    if showColors {
                        GroupBox(label: Label("Colors", systemImage: "paintpalette")
                            .font(.headline)
                            .fontWeight(.semibold)
                        ) {
                            HStack(spacing: 30) {
                                VStack(alignment: .leading) {
                                    Text("Main Color")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        ColorPicker("", selection: $serialManager.mainColor, supportsOpacity: false)
                                            .labelsHidden()
                                            .help("Choose the primary colour")
                                        let rgb = serialManager.mainColor.toRGB()
                                        Text("\(rgb.r),\(rgb.g),\(rgb.b)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .onChange(of: serialManager.mainColor) { _, newColor in
                                        colorDebounceTimer?.invalidate()
                                        colorDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                            let rgb = newColor.toRGB()
                                            serialManager.sendCommand("SET COLOR=\(rgb.r),\(rgb.g),\(rgb.b)")
                                        }
                                    }
                                }
                                if serialManager.effect == "CHASE" || serialManager.effect == "KNIGHT" {
                                    VStack(alignment: .leading) {
                                        Text("Background")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        HStack {
                                            ColorPicker("", selection: $serialManager.bgColor, supportsOpacity: false)
                                                .labelsHidden()
                                                .help("Choose the background colour for Chase/Knight")
                                            let rgb = serialManager.bgColor.toRGB()
                                            Text("\(rgb.r),\(rgb.g),\(rgb.b)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .onChange(of: serialManager.bgColor) { _, newColor in
                                            bgDebounceTimer?.invalidate()
                                            bgDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                                let rgb = newColor.toRGB()
                                                serialManager.sendCommand("SET BGCOLOR=\(rgb.r),\(rgb.g),\(rgb.b)")
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    // MARK: Gradient Editor
                    if serialManager.effect == "GRADIENT" {
                        GroupBox(label: Label("Gradient Colors", systemImage: "paintbrush")
                            .font(.headline)
                            .fontWeight(.semibold)
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                GradientBar(stops: $gradientStops, onChanged: {
                                    self.debounceGradientUpdate()
                                })
                                .frame(height: 20)
                                .padding(.horizontal, 12)
                                HStack {
                                    Button(action: addStop) {
                                        Label("Add Color", systemImage: "plus.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(gradientStops.count >= maxGradientStops)
                                    .help("Add a new colour stop (max 10)")
                                    
                                    Spacer()
                                    
                                    Text("Drag dots · Tap to pick colour · Double‑tap to remove")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    
                    // MARK: Settings
                    if serialManager.effect != "OFF" {
                        GroupBox(label: Label("Settings", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .fontWeight(.semibold)
                        ) {
                            VStack(spacing: 10) {
                                if serialManager.effect != "STATIC" {
                                    SliderWithLabel(
                                        value: $serialManager.speed,
                                        range: 0.1...5.0,
                                        label: "Speed",
                                        step: 0.1,
                                        formatter: { String(format: "%.4g", $0) }
                                    )
                                    .help("Adjust the animation speed")
                                    .onChange(of: serialManager.speed) { _, newSpeed in
                                        speedDebounceTimer?.invalidate()
                                        speedDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                            serialManager.sendCommand("SET SPEED=\(String(format: "%.4g", newSpeed))")
                                        }
                                    }
                                }
                                
                                SliderWithLabel(
                                    value: Binding(
                                        get: { Double(self.serialManager.brightness) },
                                        set: { self.serialManager.brightness = Int($0) }
                                    ),
                                    range: 0...255,
                                    label: "Brightness",
                                    step: 1,
                                    formatter: { String(Int($0)) }
                                )
                                .help("Adjust the overall brightness")
                                .onChange(of: serialManager.brightness) { _, newBrightness in
                                    brightnessDebounceTimer?.invalidate()
                                    brightnessDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                        serialManager.sendCommand("SET BRIGHT=\(newBrightness)")
                                    }
                                }
                                
                                if serialManager.effect == "GRADIENT" || serialManager.effect == "RAINBOW" {
                                    SliderWithLabel(
                                        value: $serialManager.scale,
                                        range: 0.1...4.0,
                                        label: "Scale",
                                        step: 0.1,
                                        formatter: { String(format: "%.4g", $0) }
                                    )
                                    .help("Adjust the spread or scale of the effect")
                                    .onChange(of: serialManager.scale) { _, newScale in
                                        scaleDebounceTimer?.invalidate()
                                        scaleDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                            serialManager.sendCommand("SET SCALE=\(String(format: "%.4g", newScale))")
                                        }
                                    }
                                }
                                
                                if serialManager.effect == "CHASE" || serialManager.effect == "RAINBOW" || serialManager.effect == "GRADIENT" {
                                    HStack {
                                        Toggle("Reverse Direction", isOn: Binding(
                                            get: { serialManager.direction == "REV" },
                                            set: { newValue in
                                                let dir = newValue ? "REV" : "FWD"
                                                serialManager.direction = dir
                                                serialManager.sendCommand("SET DIRECTION=\(dir)")
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                        .help("Reverse the animation direction")
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            
            Divider()
            
            // MARK: Bottom Action Bar
            HStack {
                // Profile picture (About popover)
                Button(action: { showingAboutPopover.toggle() }) {
                    ZStack(alignment: .topTrailing) {
                        Image("profile")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        
                        if updateChecker.updateAvailable {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 3, y: -3)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 3, y: -3)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("About LuMini and updates")
                .popover(isPresented: $showingAboutPopover, arrowEdge: .top) {
                    AboutView(
                        updateAvailable: $updateChecker.updateAvailable,
                        latestVersion: $updateChecker.latestVersion,
                        showingAboutPopover: $showingAboutPopover,
                        autoCheckForUpdates: $autoCheckForUpdates,
                        updateChecker: updateChecker
                    )
                }
                
                Divider().frame(height: 20)
                
                Toggle("", isOn: $launchAtBoot)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .padding(.horizontal, 2)
                    .onChange(of: launchAtBoot) { _, newValue in
                        setLaunchAtBoot(enabled: newValue)
                    }
                    .help("Automatically launch LuMini when you log in")
                Text("Login")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider().frame(height: 20)
                
                Toggle("", isOn: $serialManager.autoSleepWake)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .padding(.horizontal, 2)
                    .help("Automatically turn off the ring when your Mac sleeps")
                Text("Sleep/Wake")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("📤 GET") {
                    serialManager.getState()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                .font(.caption)
                .help("Debug: send GET command to fetch current state")
                
                Spacer().frame(width: 20)
                
                Button("Save") {
                    showingSaveAlert = true
                }
                .buttonStyle(.bordered)
                .help("Save current settings to ring EEPROM or a file")
                .confirmationDialog(
                    "Save Settings",
                    isPresented: $showingSaveAlert,
                    titleVisibility: .visible
                ) {
                    Button("Save to Ring (EEPROM)") {
                        saveToRing()
                    }
                    Button("Save to File…") {
                        presentFileSavePanel()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Choose where to save your current settings.")
                }
                
                Button("Load") {
                    showingLoadAlert = true
                }
                .buttonStyle(.bordered)
                .help("Load settings from ring EEPROM or a file")
                .confirmationDialog(
                    "Load Settings",
                    isPresented: $showingLoadAlert,
                    titleVisibility: .visible
                ) {
                    Button("Load from Ring (EEPROM)") {
                        loadFromRing()
                    }
                    Button("Load from File…") {
                        presentFileOpenPanel()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Choose where to load settings from.")
                }
                
                Button("Reset") {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .help("Reset the ring to factory defaults (clears EEPROM)")
                .confirmationDialog(
                    "Reset Ring",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        performReset()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will clear all saved settings and reset the ring to factory defaults. Are you sure?")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 700)
        .onAppear {
            serialManager.refreshPorts()
            syncStopsFromSerialManager()
            if autoCheckForUpdates {
                if let lastDate = lastUpdateCheckDate,
                   Date().timeIntervalSince(lastDate) < 86400 {
                    // skip
                } else {
                    updateChecker.performCheck(showResult: false)
                    lastUpdateCheckDate = Date()
                }
            }
        }
        .onReceive(serialManager.$gradientColors) { newColors in
            if newColors.count >= 2 {
                let count = newColors.count
                gradientStops = newColors.enumerated().map { index, color in
                    let position = CGFloat(index) / CGFloat(count - 1)
                    return GradientStop(position: position, color: color)
                }
            }
        }
        .onReceive(previewTimer) { _ in
            guard let keyWindow = NSApplication.shared.keyWindow,
                  keyWindow.title == "LuMini" else { return }
            previewTimestamp = Date()
        }
        .alert("Error", isPresented: $showingErrorAlert, presenting: errorAlertMessage) { _ in
            Button("OK") { }
        } message: { message in
            Text(message)
        }
        .alert("File Saved", isPresented: $showingSaveConfirmation) {
            Button("Reveal in Finder") {
                if let url = savedFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                savedFileURL = nil
            }
            Button("OK", role: .cancel) {
                savedFileURL = nil
            }
        } message: {
            if let url = savedFileURL {
                Text("Settings saved to:\n\(url.path)")
            } else {
                Text("Settings saved successfully.")
            }
        }
    }
    
    // MARK: - Save/Load Actions
    private func saveToRing() {
        serialManager.sendCommand("SAVE")
    }
    
    private func loadFromRing() {
        serialManager.sendCommand("LOAD")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            serialManager.getState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                syncStopsFromSerialManager()
            }
        }
    }
    
    private func presentFileSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Save Settings"
        panel.message = "Choose a name and location for your preset."
        panel.nameFieldStringValue = "MyPreset"
        let utType = UTType(filenameExtension: PresetManager.fileExtension)!
        panel.allowedContentTypes = [utType]
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let settings = SavedSettings(serialManager: serialManager, gradientStops: gradientStops)
                    try PresetManager.save(settings: settings, to: url)
                    savedFileURL = url
                    showingSaveConfirmation = true
                    print("✅ Saved to: \(url.path)")
                } catch {
                    errorAlertMessage = "Failed to save file: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func presentFileOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Load Settings"
        panel.message = "Choose a preset file to load."
        let utType = UTType(filenameExtension: PresetManager.fileExtension)!
        panel.allowedContentTypes = [utType]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let settings = try PresetManager.load(from: url)
                    settings.apply(to: serialManager, gradientStops: &gradientStops)
                    syncStopsFromSerialManager()
                    applySettingsToRing(settings: settings)
                    print("✅ Loaded from: \(url.path)")
                } catch {
                    errorAlertMessage = "Failed to load file: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func applySettingsToRing(settings: SavedSettings) {
        if settings.effect == "GRADIENT" {
            sendGradientToRing()
        } else {
            serialManager.sendCommand("SET EFFECT=\(settings.effect)")
        }
        serialManager.sendCommand("SET DIRECTION=\(settings.direction)")
        let mainRGB = settings.mainColor
        serialManager.sendCommand("SET COLOR=\(mainRGB.r),\(mainRGB.g),\(mainRGB.b)")
        let bgRGB = settings.bgColor
        serialManager.sendCommand("SET BGCOLOR=\(bgRGB.r),\(bgRGB.g),\(bgRGB.b)")
        serialManager.sendCommand("SET SPEED=\(String(format: "%.4g", settings.speed))")
        serialManager.sendCommand("SET BRIGHT=\(settings.brightness)")
        serialManager.sendCommand("SET SCALE=\(String(format: "%.4g", settings.scale))")
    }
    
    // MARK: - Launch at Boot
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
    
    // MARK: - Helpers
    private func debounceGradientUpdate() {
        gradientUpdateTimer?.invalidate()
        gradientUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            updateGradientFromStops()
        }
    }
    
    private func syncStopsFromSerialManager() {
        let colors = serialManager.gradientColors
        guard colors.count >= 2 else { return }
        gradientStops = colors.enumerated().map { index, color in
            let position = CGFloat(index) / CGFloat(colors.count - 1)
            return GradientStop(position: position, color: color)
        }
    }
    
    private func updateGradientFromStops() {
        let sortedStops = gradientStops.sorted { $0.position < $1.position }
        let colors = sortedStops.map { $0.color }
        serialManager.gradientColors = colors
        sendGradientToRing()
    }
    
    private func sendGradientToRing() {
        let sortedStops = gradientStops.sorted { $0.position < $1.position }
        guard sortedStops.count >= 2 else { return }
        var cmd = "SET EFFECT=GRADIENT"
        for (index, stop) in sortedStops.enumerated() {
            let rgb = stop.color.toRGB()
            cmd += " COLOR\(index+1)=\(rgb.r),\(rgb.g),\(rgb.b)"
        }
        serialManager.sendCommand(cmd)
    }
    
    private func addStop() {
        guard gradientStops.count < maxGradientStops else { return }
        let sorted = gradientStops.sorted { $0.position < $1.position }
        var maxGap: CGFloat = 0
        var insertIndex = 0
        for i in 0..<sorted.count-1 {
            let gap = sorted[i+1].position - sorted[i].position
            if gap > maxGap {
                maxGap = gap
                insertIndex = i
            }
        }
        var newPosition: CGFloat = 0.5
        if sorted.count > 1 {
            newPosition = (sorted[insertIndex].position + sorted[insertIndex+1].position) / 2
        }
        let leftColor = sorted[insertIndex].color
        let rightColor = sorted[insertIndex+1].color
        let avgColor = averageColor(left: leftColor, right: rightColor)
        let newStop = GradientStop(position: newPosition, color: avgColor)
        gradientStops.append(newStop)
        updateGradientFromStops()
    }
    
    private func averageColor(left: Color, right: Color) -> Color {
        let l = NSColor(left).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = NSColor(right).usingColorSpace(.deviceRGB) ?? NSColor.black
        let red = (l.redComponent + r.redComponent) / 2
        let green = (l.greenComponent + r.greenComponent) / 2
        let blue = (l.blueComponent + r.blueComponent) / 2
        return Color(red: red, green: green, blue: blue)
    }
    
    private func performReset() {
        serialManager.sendCommand("EEPROM_CLEAR")
        resetUIState()
    }
    
    private func resetUIState() {
        colorDebounceTimer?.invalidate()
        bgDebounceTimer?.invalidate()
        speedDebounceTimer?.invalidate()
        brightnessDebounceTimer?.invalidate()
        scaleDebounceTimer?.invalidate()
        serialManager.effect = "BREATHE"
        serialManager.mainColor = .white
        serialManager.bgColor = .black
        serialManager.speed = 1.0
        serialManager.brightness = 255
        serialManager.scale = 1.0
        serialManager.direction = "FWD"
        let pureRed = Color(red: 1, green: 0, blue: 0)
        let pureBlue = Color(red: 0, green: 0, blue: 1)
        serialManager.gradientColors = [pureRed, pureBlue]
        gradientStops = [
            GradientStop(position: 0.0, color: pureRed),
            GradientStop(position: 1.0, color: pureBlue)
        ]
    }
    
    // MARK: - Preview Computation
    private func computePreviewColors() -> [Color] {
        let numLEDs = 24
        var colors: [Color] = []
        let effect = serialManager.effect
        let mainColor = serialManager.mainColor
        let bgColor = serialManager.bgColor
        let speed = serialManager.speed
        let scale = serialManager.scale
        let direction = serialManager.direction
        let dirSign: Double = (direction == "FWD") ? 1.0 : -1.0
        let now = previewTimestamp.timeIntervalSince1970
        
        let sortedStops = gradientStops.sorted { $0.position < $1.position }
        let gradientColors = sortedStops.map { $0.color }
        
        let speedMultiplier: Double
        switch effect {
        case "GRADIENT": speedMultiplier = 1.0
        case "RAINBOW": speedMultiplier = rainbowSpeedMultiplier
        case "BREATHE": speedMultiplier = breatheSpeedMultiplier
        case "CHASE": speedMultiplier = chaseSpeedMultiplier
        case "KNIGHT": speedMultiplier = knightSpeedMultiplier
        default: speedMultiplier = 1.0
        }
        
        switch effect {
        case "STATIC":
            colors = Array(repeating: mainColor, count: numLEDs)
        case "CHASE":
            let pixelsPerSecond = speed * 6.0 * speedMultiplier
            var pos = (now * pixelsPerSecond * dirSign).truncatingRemainder(dividingBy: Double(numLEDs))
            if pos < 0 { pos += Double(numLEDs) }
            for i in 0..<numLEDs {
                var color = bgColor
                var d = abs(Double(i) - pos)
                if d > Double(numLEDs) / 2.0 { d = Double(numLEDs) - d }
                let b = exp(-(d * d) / 1.2)
                let brightness = min(1.0, b)
                if brightness > 0.001 {
                    let r = bgColor.rgba.red + (mainColor.rgba.red - bgColor.rgba.red) * brightness
                    let g = bgColor.rgba.green + (mainColor.rgba.green - bgColor.rgba.green) * brightness
                    let bl = bgColor.rgba.blue + (mainColor.rgba.blue - bgColor.rgba.blue) * brightness
                    color = Color(red: r, green: g, blue: bl)
                }
                colors.append(color)
            }
        case "KNIGHT":
            let pixelsPerSecond = speed * 5.0 * speedMultiplier
            let t = now * pixelsPerSecond
            let period = Double(numLEDs) * 2.0 - 2.0
            var pos = t.truncatingRemainder(dividingBy: period)
            if pos >= Double(numLEDs) { pos = period - pos }
            for i in 0..<numLEDs {
                var color = bgColor
                let d = abs(Double(i) - pos)
                if d > 2.5 { colors.append(color); continue }
                let b = exp(-(d * d) / 1.2)
                let brightness = min(1.0, b)
                if brightness > 0.001 {
                    let r = bgColor.rgba.red + (mainColor.rgba.red - bgColor.rgba.red) * brightness
                    let g = bgColor.rgba.green + (mainColor.rgba.green - bgColor.rgba.green) * brightness
                    let bl = bgColor.rgba.blue + (mainColor.rgba.blue - bgColor.rgba.blue) * brightness
                    color = Color(red: r, green: g, blue: bl)
                }
                colors.append(color)
            }
        case "RAINBOW":
            let step = (255.0 / Double(numLEDs)) / max(scale, 0.1)
            let offset = now * speed * 60.0 * speedMultiplier * dirSign
            for i in 0..<numLEDs {
                var hue = offset + Double(i) * step
                hue = hue.truncatingRemainder(dividingBy: 255.0)
                if hue < 0 { hue += 255.0 }
                colors.append(Color(hue: hue / 255.0, saturation: 1.0, brightness: 1.0))
            }
        case "BREATHE":
            let phase = sin(now * speed * 0.5 * speedMultiplier)
            let bright = (phase + 1.0) / 2.0
            colors = Array(repeating: mainColor.opacity(bright), count: numLEDs)
        case "GRADIENT":
            if gradientColors.isEmpty {
                colors = Array(repeating: .black, count: numLEDs)
            } else {
                let invScale = 1.0 / max(scale, 0.1)
                var rotation = (now * speed * 0.15 * dirSign)
                    .truncatingRemainder(dividingBy: 1.0)
                if rotation < 0 { rotation += 1.0 }
                for i in 0..<numLEDs {
                    let position = (Double(i) / Double(numLEDs)) * invScale + rotation
                    let wrappedPos = (position.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0)
                    colors.append(interpolateCyclicEvenly(at: wrappedPos, stops: gradientColors))
                }
            }
        default:
            colors = Array(repeating: .black, count: numLEDs)
        }
        return colors
    }
    
    private func interpolateCyclicEvenly(at position: Double, stops: [Color]) -> Color {
        guard stops.count >= 2 else { return stops.first ?? .black }
        let count = stops.count
        let segment = position * Double(count)
        let index = Int(floor(segment))
        let frac = segment - Double(index)
        let idx0 = index % count
        let idx1 = (index + 1) % count
        let c0 = NSColor(stops[idx0]).usingColorSpace(.deviceRGB) ?? NSColor.black
        let c1 = NSColor(stops[idx1]).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = c0.redComponent + (c1.redComponent - c0.redComponent) * frac
        let g = c0.greenComponent + (c1.greenComponent - c0.greenComponent) * frac
        let b = c0.blueComponent + (c1.blueComponent - c0.blueComponent) * frac
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - HeaderRingView (bigger dots for the logo)
struct HeaderRingView: View {
    let colors: [Color]
    let ledCount: Int
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size/2, y: size/2)
            let radius = size/2 - 4
            // Bigger dots: min radius 3.5, multiplier 0.15 (was 3, 0.12)
            let ledRadius: CGFloat = max(3.5, radius * 0.15)
            
            ZStack {
                ForEach(0..<min(colors.count, ledCount), id: \.self) { index in
                    let angle = Angle(degrees: Double(index) / Double(ledCount) * 360.0 - 90.0)
                    let x = center.x + radius * cos(CGFloat(angle.radians))
                    let y = center.y + radius * sin(CGFloat(angle.radians))
                    
                    Circle()
                        .fill(colors[index])
                        .frame(width: ledRadius * 2, height: ledRadius * 2)
                        .position(x: x, y: y)
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - RingView (original, unchanged for preview)
struct RingView: View {
    let colors: [Color]
    let ledCount: Int
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size/2, y: size/2)
            let radius = size/2 - 4
            let ledRadius: CGFloat = max(3, radius * 0.12)
            
            ZStack {
                ForEach(0..<min(colors.count, ledCount), id: \.self) { index in
                    let angle = Angle(degrees: Double(index) / Double(ledCount) * 360.0 - 90.0)
                    let x = center.x + radius * cos(CGFloat(angle.radians))
                    let y = center.y + radius * sin(CGFloat(angle.radians))
                    
                    Circle()
                        .fill(colors[index])
                        .frame(width: ledRadius * 2, height: ledRadius * 2)
                        .position(x: x, y: y)
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - Gradient Bar
struct GradientBar: View {
    @Binding var stops: [GradientStop]
    var onChanged: () -> Void
    
    @State private var activeIndex: Int? = nil
    @State private var pickerColor: Color = .black
    @StateObject private var wellHolder = WellHolder()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                let sorted = stops.sorted { $0.position < $1.position }
                let colors = sorted.map { $0.color }
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                
                ForEach(stops) { stop in
                    let index = stops.firstIndex(where: { $0.id == stop.id })!
                    let x = stop.position * geometry.size.width
                    
                    Circle()
                        .fill(stop.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                                .opacity(activeIndex == index ? 1 : 0)
                        )
                        .shadow(radius: 2)
                        .position(x: x, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if activeIndex != nil {
                                        activeIndex = nil
                                        wellHolder.close()
                                    }
                                    let newX = min(max(value.location.x, 0), geometry.size.width)
                                    let newPosition = newX / geometry.size.width
                                    if let idx = stops.firstIndex(where: { $0.id == stop.id }) {
                                        stops[idx].position = newPosition
                                        stops.sort { $0.position < $1.position }
                                        onChanged()
                                    }
                                }
                        )
                        .onTapGesture(count: 1) {
                            wellHolder.close()
                            pickerColor = stop.color
                            activeIndex = index
                            wellHolder.open()
                        }
                        .onTapGesture(count: 2) {
                            if stops.count > 2 {
                                stops.remove(at: index)
                                onChanged()
                            }
                        }
                }
                
                NativeColorWellWithHolder(
                    color: Binding(
                        get: { pickerColor },
                        set: { newColor in
                            pickerColor = newColor
                            if let idx = activeIndex, idx < stops.count {
                                stops[idx].color = newColor
                                onChanged()
                            }
                        }
                    ),
                    wellHolder: wellHolder,
                    onColorChange: { _ in }
                )
                .frame(width: 0, height: 0)
                .opacity(0)
            }
        }
    }
}

// MARK: - SliderWithLabel
struct SliderWithLabel: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let step: Double
    let formatter: (Double) -> String
    
    @State private var textFieldValue: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        let rounded = (newValue / step).rounded() * step
                        value = min(max(rounded, range.lowerBound), range.upperBound)
                        textFieldValue = formatter(value)
                    }
                ),
                in: range
            )
            
            TextField("", text: $textFieldValue)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .onSubmit {
                    updateValueFromText()
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        updateValueFromText()
                    }
                }
                .onAppear {
                    textFieldValue = formatter(value)
                }
        }
        .onChange(of: value) { _, newValue in
            textFieldValue = formatter(newValue)
        }
    }
    
    private func updateValueFromText() {
        let trimmed = textFieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newValue = Double(trimmed) {
            let clamped = min(max(newValue, range.lowerBound), range.upperBound)
            value = clamped
            textFieldValue = formatter(clamped)
        } else {
            textFieldValue = formatter(value)
        }
    }
}
