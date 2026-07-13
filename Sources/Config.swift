import Foundation
import Carbon
import OSLog

let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/ClipboardTyper")
let configFile = configDir.appendingPathComponent("config.json")

// MARK: - HotKey Display Protocol

// Shared protocol to eliminate duplicate displayString logic between
// AppConfig (persisted) and HotKeyConfig (transient, used during recording).
protocol HotKeyDisplayable {
    var keyCode: UInt32 { get }
    var control: Bool { get }
    var option: Bool { get }
    var shift: Bool { get }
    var command: Bool { get }
}

extension HotKeyDisplayable {
    var displayString: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        s += keyCodeToDisplay(keyCode, shift: shift)
        return s
    }
}

// MARK: - App Config

struct AppConfig: Codable, HotKeyDisplayable {
    var keyCode: UInt32
    var control: Bool
    var option: Bool
    var shift: Bool
    var command: Bool
    
    // Speed parameters stored in microseconds for precision.
    // UI shows milliseconds for readability; conversion happens in SpeedSettingsWindow.
    var interKeyDelay: UInt32
    var interChunkDelay: UInt32
    var chunkSize: Int
    var batchSize: Int
    
    static let defaultConfig = AppConfig(
        keyCode: 9, control: true, option: true, shift: false, command: false,
        interKeyDelay: 5000,
        interChunkDelay: 10000,
        chunkSize: 100,
        batchSize: 10
    )
    
    // Carbon API requires modifiers as a bitmask. This converts our booleans
    // into the format expected by RegisterEventHotKey.
    var carbonModifiers: UInt32 {
        var mods: UInt32 = 0
        if control { mods |= UInt32(controlKey) }
        if option { mods |= UInt32(optionKey) }
        if shift { mods |= UInt32(shiftKey) }
        if command { mods |= UInt32(cmdKey) }
        return mods
    }
}

// MARK: - HotKey Config

// Lightweight struct used only during hotkey recording. Not persisted.
// Separate from AppConfig because recording doesn't need speed parameters.
struct HotKeyConfig: HotKeyDisplayable {
    var keyCode: UInt32
    var control: Bool
    var option: Bool
    var shift: Bool
    var command: Bool
}

// MARK: - Config Load/Save

func loadConfig() -> AppConfig {
    guard let data = try? Data(contentsOf: configFile),
          let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
        return .defaultConfig
    }
    return config
}

func saveConfig(_ config: AppConfig) {
    do {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: configFile)
    } catch {
        Logger.app.error("Failed to save config: \(error.localizedDescription)")
    }
}
