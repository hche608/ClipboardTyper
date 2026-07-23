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
    // Extra delay when shift state changes between batches.
    // RDP needs time to process shift up/down transitions; without this,
    // fast alternation (e.g. "aAbBcC") produces wrong characters.
    var shiftToggleDelay: UInt32
    
    static let defaultConfig = AppConfig(
        keyCode: 9, control: true, option: true, shift: false, command: false,
        interKeyDelay: 5000,
        interChunkDelay: 10000,
        chunkSize: 100,
        batchSize: 10,
        shiftToggleDelay: 30000
    )
    
    // Custom decoder: provides defaults for fields added in later versions,
    // so existing config files without shiftToggleDelay don't fail to parse.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try c.decode(UInt32.self, forKey: .keyCode)
        control = try c.decode(Bool.self, forKey: .control)
        option = try c.decode(Bool.self, forKey: .option)
        shift = try c.decode(Bool.self, forKey: .shift)
        command = try c.decode(Bool.self, forKey: .command)
        interKeyDelay = try c.decode(UInt32.self, forKey: .interKeyDelay)
        interChunkDelay = try c.decode(UInt32.self, forKey: .interChunkDelay)
        chunkSize = try c.decode(Int.self, forKey: .chunkSize)
        batchSize = try c.decode(Int.self, forKey: .batchSize)
        shiftToggleDelay = try c.decodeIfPresent(UInt32.self, forKey: .shiftToggleDelay) ?? Self.defaultConfig.shiftToggleDelay
    }
    
    init(keyCode: UInt32, control: Bool, option: Bool, shift: Bool, command: Bool,
         interKeyDelay: UInt32, interChunkDelay: UInt32, chunkSize: Int, batchSize: Int,
         shiftToggleDelay: UInt32) {
        self.keyCode = keyCode
        self.control = control
        self.option = option
        self.shift = shift
        self.command = command
        self.interKeyDelay = interKeyDelay
        self.interChunkDelay = interChunkDelay
        self.chunkSize = chunkSize
        self.batchSize = batchSize
        self.shiftToggleDelay = shiftToggleDelay
    }
    
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
