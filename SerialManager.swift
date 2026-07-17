//
//  SerialManager.swift
//  LuMini
//
//  Created by Jannes ‎ on 07/07/2026.
//

import Foundation
import IOKit
import IOKit.serial
import Combine
import SwiftUI
import AppKit

class SerialManager: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentPort: String = ""
    @Published var isPoweredOn: Bool = true
    @Published var effect: String = "BREATHE"
    @Published var direction: String = "FWD"
    @Published var mainColor: Color = .white
    @Published var bgColor: Color = .black
    @Published var speed: Double = 1.0
    @Published var brightness: Int = 255
    @Published var scale: Double = 1.0
    @Published var gradientColors: [Color] = [
        Color(red: 1.0, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.0, blue: 1.0)
    ]
    @Published var autoSleepWake: Bool = true
    
    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.ledring.serial", qos: .userInitiated)
    private var incomingBuffer = ""
    private var ignoreIndividualColors = false
    
    override init() {
        super.init()
        print("🔌 SerialManager initialized")
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        refreshPorts()
    }
    
    deinit {
        disconnect()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func systemWillSleep(_ notification: Notification) {
        guard autoSleepWake else { return }
        print("💤 System sleeping – turning ring OFF")
        if isPoweredOn {
            sendCommand("OFF")
            DispatchQueue.main.async { self.isPoweredOn = false }
        }
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        guard autoSleepWake else { return }
        print("⏰ System woke – turning ring ON")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendCommand("ON")
            DispatchQueue.main.async { self.isPoweredOn = true }
        }
    }
    
    func refreshPorts() {
        let ports = findSerialPorts()
        print("Found \(ports.count) serial ports:")
        for port in ports { print("  📍 \(port)") }
        let usbPorts = ports.filter {
            $0.contains("usbmodem") || $0.contains("ttyACM") || $0.contains("tty.usbmodem")
        }
        let selectedPort = usbPorts.first ?? ports.first
        if let port = selectedPort {
            connect(to: port)
        } else {
            print("❌ No serial ports found")
        }
    }
    
    func findSerialPorts() -> [String] {
        var portPaths: [String] = []
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(kIOSerialBSDServiceValue),
            &iterator
        )
        guard result == KERN_SUCCESS else { return portPaths }
        var service: io_object_t = 1
        while service != 0 {
            service = IOIteratorNext(iterator)
            if service != 0 {
                if let path = getSerialPortPath(service: service) {
                    portPaths.append(path)
                }
                IOObjectRelease(service)
            }
        }
        IOObjectRelease(iterator)
        return portPaths
    }
    
    private func getSerialPortPath(service: io_object_t) -> String? {
        let bsdName = IORegistryEntryCreateCFProperty(
            service,
            kIOCalloutDeviceKey as CFString,
            kCFAllocatorDefault,
            0
        )
        return bsdName?.takeUnretainedValue() as? String
    }
    
    func connect(to path: String) {
        disconnect()
        print("🔗 Connecting to \(path)...")
        fileDescriptor = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor != -1 else {
            print("❌ Failed to open port: \(String(cString: strerror(errno)))")
            return
        }
        if configurePort(fileDescriptor) {
            isConnected = true
            currentPort = path
            print("✅ Connected to \(path)")
            setupReadHandler()
            getState()
        } else {
            close(fileDescriptor)
            fileDescriptor = -1
            isConnected = false
            currentPort = ""
        }
    }
    
    func disconnect() {
        if let source = readSource {
            source.cancel()
            readSource = nil
        }
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        isConnected = false
        currentPort = ""
        print("🔌 Disconnected")
    }
    
    private func configurePort(_ fd: Int32) -> Bool {
        var settings = termios()
        guard tcgetattr(fd, &settings) == 0 else { return false }
        cfsetspeed(&settings, speed_t(B115200))
        settings.c_cflag &= ~tcflag_t(CSIZE)
        settings.c_cflag |= tcflag_t(CS8)
        settings.c_cflag &= ~tcflag_t(PARENB)
        settings.c_cflag &= ~tcflag_t(CSTOPB)
        settings.c_cflag &= ~tcflag_t(CRTSCTS)
        settings.c_cflag |= tcflag_t(CREAD | CLOCAL)
        settings.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)
        settings.c_oflag &= ~tcflag_t(OPOST)
        settings.c_cc.0 = 1
        settings.c_cc.1 = 10
        return tcsetattr(fd, TCSANOW, &settings) == 0
    }
    
    private func setupReadHandler() {
        guard fileDescriptor != -1 else { return }
        let fd = fileDescriptor
        readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource?.setEventHandler { [weak self] in self?.readData() }
        readSource?.setCancelHandler { [weak self] in self?.fileDescriptor = -1 }
        readSource?.resume()
    }
    
    private func readData() {
        guard fileDescriptor != -1 else { return }
        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(fileDescriptor, &buffer, buffer.count)
        if bytesRead > 0 {
            let data = Data(bytes: buffer, count: bytesRead)
            if let chunk = String(data: data, encoding: .utf8) {
                incomingBuffer += chunk
                let lines = incomingBuffer.components(separatedBy: "\n")
                incomingBuffer = lines.last ?? ""
                for i in 0..<lines.count-1 {
                    let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        handleResponse(line)
                    }
                }
            }
        } else if bytesRead == -1 && errno != EAGAIN {
            print("⚠️ Read error: \(String(cString: strerror(errno)))")
            DispatchQueue.main.async { self.isConnected = false }
        }
    }
    
    func sendCommand(_ command: String) {
        guard fileDescriptor != -1, isConnected else {
            print("⚠️ Not connected")
            return
        }
        let cmd = command + "\n"
        guard let data = cmd.data(using: .utf8) else { return }
        _ = data.withUnsafeBytes { write(fileDescriptor, $0.baseAddress, data.count) }
        print("📤 Sent: \(command)")
    }
    
    func togglePower() {
        isPoweredOn.toggle()
        sendCommand(isPoweredOn ? "ON" : "OFF")
    }
    
    func getState() {
        sendCommand("GET")
    }
    
    private func handleResponse(_ response: String) {
        print("📥 Received: \(response)")
        if response.contains("=") {
            parseStateResponse(response)
        }
    }
    
    private func parseStateResponse(_ response: String) {
        let pairs = response.split(separator: " ")
        var hasGradientField = false
        var gradientColorsFromField: [Color] = []
        var gradientCountFromField = 0
        
        // First pass: look for GRADIENT field
        for pair in pairs {
            let parts = pair.split(separator: "=")
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "GRADIENT" {
                hasGradientField = true
                let gradientParts = value.split(separator: ":")
                if gradientParts.count == 2, let count = Int(gradientParts[0]) {
                    gradientCountFromField = count
                    let colorValues = gradientParts[1].split(separator: ",").compactMap { Int($0) }
                    var colors: [Color] = []
                    for i in stride(from: 0, to: min(colorValues.count, count * 3), by: 3) {
                        if i+2 < colorValues.count {
                            colors.append(Color(red: Double(colorValues[i])/255,
                                                green: Double(colorValues[i+1])/255,
                                                blue: Double(colorValues[i+2])/255))
                        }
                    }
                    gradientColorsFromField = colors
                }
                break
            }
        }
        
        // Second pass: apply all values
        DispatchQueue.main.async {
            for pair in pairs {
                let parts = pair.split(separator: "=")
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                switch key {
                case "EFFECT":
                    self.effect = value
                    print("  ✅ Effect set to: \(value)")
                case "DIRECTION":
                    self.direction = value
                case "COLOR":
                    let rgb = value.split(separator: ",").compactMap { Int($0) }
                    if rgb.count == 3 {
                        self.mainColor = Color(red: Double(rgb[0])/255, green: Double(rgb[1])/255, blue: Double(rgb[2])/255)
                        print("  ✅ Main color set to: \(rgb)")
                    }
                case "BG":
                    let rgb = value.split(separator: ",").compactMap { Int($0) }
                    if rgb.count == 3 {
                        self.bgColor = Color(red: Double(rgb[0])/255, green: Double(rgb[1])/255, blue: Double(rgb[2])/255)
                        print("  ✅ Background color set to: \(rgb)")
                    }
                case "SPEED":
                    if let s = Double(value) {
                        self.speed = s
                        print("  ✅ Speed set to: \(s)")
                    }
                case "BRIGHT":
                    if let b = Int(value) {
                        self.brightness = b
                        print("  ✅ Brightness set to: \(b)")
                    }
                case "SCALE":
                    if let s = Double(value) {
                        self.scale = s
                        print("  ✅ Scale set to: \(s)")
                    }
                case "GRADIENT":
                    // Already handled; skip
                    break
                default:
                    break
                }
            }
            
            // If we had a GRADIENT field, use it
            if hasGradientField && gradientCountFromField > 0 {
                self.gradientColors = gradientColorsFromField
                print("  ✅ Gradient colors updated from GRADIENT field: \(gradientColorsFromField.count) stops")
            } else {
                // No GRADIENT field: build from COLORx lines
                var colorMap: [Int: Color] = [:]
                for pair in pairs {
                    let parts = pair.split(separator: "=")
                    guard parts.count == 2 else { continue }
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if key.hasPrefix("COLOR") && key.count > 5 {
                        let index = Int(key.dropFirst(5)) ?? 0
                        if index >= 1 && index <= 10 {
                            let rgb = value.split(separator: ",").compactMap { Int($0) }
                            if rgb.count == 3 {
                                colorMap[index] = Color(red: Double(rgb[0])/255,
                                                        green: Double(rgb[1])/255,
                                                        blue: Double(rgb[2])/255)
                            }
                        }
                    }
                }
                // Determine gradient count by finding the highest index with a non-black color
                var count = 0
                let sortedIndices = colorMap.keys.sorted()
                for idx in sortedIndices {
                    if let color = colorMap[idx], color != Color(red: 0, green: 0, blue: 0) {
                        count = max(count, idx)
                    }
                }
                var colors: [Color] = []
                for i in 1...count {
                    if let color = colorMap[i] {
                        colors.append(color)
                    } else {
                        colors.append(.black)
                    }
                }
                if colors.count >= 2 {
                    self.gradientColors = colors
                    print("  ✅ Gradient colors updated from COLORx lines: \(colors.count) stops")
                } else {
                    print("  ⚠️ Could not determine gradient colors from COLORx lines, keeping previous")
                }
            }
        }
    }
}
