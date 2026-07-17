//
//  LEDRingIntents.swift
//  LuMini
//
//  Created by Jannes ‎ on 11/07/2026.
//

import AppIntents
import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Shared Serial Manager (singleton)
@MainActor
final class RingController {
    static let shared = RingController()
    let serialManager = SerialManager()
    private init() {}
}

// MARK: - Intent Helper
@MainActor
enum IntentHelper {
    static func ensureConnected() -> Bool {
        return RingController.shared.serialManager.isConnected
    }
    
    static func sendCommand(_ command: String) {
        RingController.shared.serialManager.sendCommand(command)
    }
    
    static func loadPreset(from url: URL) -> Bool {
        do {
            let settings = try PresetManager.load(from: url)
            var gradientStops = RingController.shared.serialManager.gradientColors.enumerated().map { index, color in
                let position = CGFloat(index) / CGFloat(RingController.shared.serialManager.gradientColors.count - 1)
                return GradientStop(position: position, color: color)
            }
            settings.apply(to: RingController.shared.serialManager, gradientStops: &gradientStops)
            
            if settings.effect == "GRADIENT" {
                let sortedStops = gradientStops.sorted { $0.position < $1.position }
                var cmd = "SET EFFECT=GRADIENT"
                for (index, stop) in sortedStops.enumerated() {
                    let rgb = stop.color.toRGB()
                    cmd += " COLOR\(index+1)=\(rgb.r),\(rgb.g),\(rgb.b)"
                }
                sendCommand(cmd)
            } else {
                sendCommand("SET EFFECT=\(settings.effect)")
            }
            sendCommand("SET DIRECTION=\(settings.direction)")
            let main = settings.mainColor
            sendCommand("SET COLOR=\(main.r),\(main.g),\(main.b)")
            let bg = settings.bgColor
            sendCommand("SET BGCOLOR=\(bg.r),\(bg.g),\(bg.b)")
            sendCommand("SET SPEED=\(String(format: "%.4g", settings.speed))")
            sendCommand("SET BRIGHT=\(settings.brightness)")
            sendCommand("SET SCALE=\(String(format: "%.4g", settings.scale))")
            return true
        } catch {
            print("Intent: Failed to load preset: \(error)")
            return false
        }
    }
}

// MARK: - Power On Intent
struct SetPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Power State"
    static var description = IntentDescription("Turn the LED ring on or off.")
    
    @Parameter(title: "State")
    var state: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentHelper.ensureConnected() else {
            throw NSError(domain: "LEDRing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ring not connected."])
        }
        IntentHelper.sendCommand(state ? "ON" : "OFF")
        RingController.shared.serialManager.isPoweredOn = state
        return .result()
    }
}

// MARK: - Toggle Power Intent
struct TogglePowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Power"
    static var description = IntentDescription("Toggle the LED ring power.")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentHelper.ensureConnected() else {
            throw NSError(domain: "LEDRing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ring not connected."])
        }
        let current = RingController.shared.serialManager.isPoweredOn
        let newState = !current
        IntentHelper.sendCommand(newState ? "ON" : "OFF")
        RingController.shared.serialManager.isPoweredOn = newState
        return .result()
    }
}

// MARK: - Load Preset Intent (handles both URL and path string)
struct LoadPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Load Preset from File"
    static var description = IntentDescription("Load a preset from a .rgb file.")
    
    @Parameter(title: "File URL")
    var fileURL: String   // <-- changed from URL to String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentHelper.ensureConnected() else {
            throw NSError(domain: "LEDRing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ring not connected."])
        }
        
        // Convert the string to a proper file URL (handles spaces and special characters)
        guard let url = URL(string: fileURL) ?? URL(string: fileURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "") else {
            throw NSError(domain: "LEDRing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL."])
        }
        
        // Handle file:// scheme if present
        let finalURL: URL
        if url.scheme == "file" {
            finalURL = url
        } else {
            // If it's a plain path, convert to file URL
            finalURL = URL(fileURLWithPath: fileURL)
        }
        
        guard FileManager.default.fileExists(atPath: finalURL.path) else {
            throw NSError(domain: "LEDRing", code: 3, userInfo: [NSLocalizedDescriptionKey: "File does not exist."])
        }
        guard finalURL.pathExtension == "rgb" else {
            throw NSError(domain: "LEDRing", code: 4, userInfo: [NSLocalizedDescriptionKey: "File must have .rgb extension."])
        }
        let success = IntentHelper.loadPreset(from: finalURL)
        if !success {
            throw NSError(domain: "LEDRing", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to load preset."])
        }
        return .result()
    }
}

// MARK: - Set Effect Intent
struct SetEffectIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Effect"
    static var description = IntentDescription("Set the effect to one of the available effects.")
    
    @Parameter(title: "Effect")
    var effect: EffectEnum
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentHelper.ensureConnected() else {
            throw NSError(domain: "LEDRing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ring not connected."])
        }
        IntentHelper.sendCommand("SET EFFECT=\(effect.rawValue)")
        return .result()
    }
}

enum EffectEnum: String, AppEnum {
    case staticEffect = "STATIC"
    case breathe = "BREATHE"
    case chase = "CHASE"
    case knight = "KNIGHT"
    case rainbow = "RAINBOW"
    case gradient = "GRADIENT"
    case off = "OFF"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Effect"
    static var caseDisplayRepresentations: [EffectEnum: DisplayRepresentation] = [
        .staticEffect: "Static",
        .breathe: "Breathe",
        .chase: "Chase",
        .knight: "Knight",
        .rainbow: "Rainbow",
        .gradient: "Gradient",
        .off: "Off"
    ]
}
