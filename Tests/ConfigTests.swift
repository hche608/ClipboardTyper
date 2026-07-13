import XCTest
import Foundation
@testable import ClipboardTyper

// MARK: - Config Tests

final class ConfigTests: XCTestCase {
    // MARK: - AppConfig Default Values

    func testDefaultConfigValues() {
        let config = AppConfig.defaultConfig
        XCTAssertEqual(config.keyCode, 9, "Default keyCode should be 9 (V key)")
        XCTAssertTrue(config.control)
        XCTAssertTrue(config.option)
        XCTAssertFalse(config.shift)
        XCTAssertFalse(config.command)
        XCTAssertEqual(config.interKeyDelay, 5000)
        XCTAssertEqual(config.interChunkDelay, 10000)
        XCTAssertEqual(config.chunkSize, 100)
        XCTAssertEqual(config.batchSize, 10)
    }

    // MARK: - Carbon Modifiers

    func testCarbonModifiersControlOption() {
        let config = AppConfig.defaultConfig
        let mods = config.carbonModifiers
        XCTAssertNotEqual(mods & 0x1000, 0, "Control bit should be set")
        XCTAssertNotEqual(mods & 0x0800, 0, "Option bit should be set")
        XCTAssertEqual(mods & 0x0200, 0, "Shift bit should not be set")
        XCTAssertEqual(mods & 0x0100, 0, "Command bit should not be set")
    }

    func testCarbonModifiersAll() {
        var config = AppConfig.defaultConfig
        config.control = true
        config.option = true
        config.shift = true
        config.command = true
        let mods = config.carbonModifiers
        XCTAssertNotEqual(mods & 0x1000, 0, "Control bit should be set")
        XCTAssertNotEqual(mods & 0x0800, 0, "Option bit should be set")
        XCTAssertNotEqual(mods & 0x0200, 0, "Shift bit should be set")
        XCTAssertNotEqual(mods & 0x0100, 0, "Command bit should be set")
    }

    func testCarbonModifiersNone() {
        var config = AppConfig.defaultConfig
        config.control = false
        config.option = false
        config.shift = false
        config.command = false
        XCTAssertEqual(config.carbonModifiers, 0)
    }

    // MARK: - Display String

    func testDisplayStringModifiers() {
        let config = HotKeyConfig(keyCode: 9, control: true, option: true, shift: false, command: false)
        let display = config.displayString
        XCTAssertTrue(display.contains("⌃"), "Should contain control symbol")
        XCTAssertTrue(display.contains("⌥"), "Should contain option symbol")
        XCTAssertFalse(display.contains("⇧"), "Should not contain shift symbol")
        XCTAssertFalse(display.contains("⌘"), "Should not contain command symbol")
    }

    func testDisplayStringAllModifiersOrder() {
        let config = HotKeyConfig(keyCode: 9, control: true, option: true, shift: true, command: true)
        let display = config.displayString
        // Verify order: ⌃⌥⇧⌘
        guard let controlIdx = display.firstIndex(of: "⌃"),
              let optionIdx = display.firstIndex(of: "⌥"),
              let shiftIdx = display.firstIndex(of: "⇧"),
              let commandIdx = display.firstIndex(of: "⌘") else {
            XCTFail("All modifier symbols should be present")
            return
        }
        XCTAssertLessThan(controlIdx, optionIdx)
        XCTAssertLessThan(optionIdx, shiftIdx)
        XCTAssertLessThan(shiftIdx, commandIdx)
    }

    // MARK: - Codable Round-trip

    func testCodableRoundTrip() throws {
        let original = AppConfig.defaultConfig
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.keyCode, original.keyCode)
        XCTAssertEqual(decoded.control, original.control)
        XCTAssertEqual(decoded.option, original.option)
        XCTAssertEqual(decoded.shift, original.shift)
        XCTAssertEqual(decoded.command, original.command)
        XCTAssertEqual(decoded.interKeyDelay, original.interKeyDelay)
        XCTAssertEqual(decoded.interChunkDelay, original.interChunkDelay)
        XCTAssertEqual(decoded.chunkSize, original.chunkSize)
        XCTAssertEqual(decoded.batchSize, original.batchSize)
    }

    func testCodableCustomValues() throws {
        var config = AppConfig.defaultConfig
        config.keyCode = 36
        config.control = false
        config.command = true
        config.interKeyDelay = 20000
        config.batchSize = 5

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.keyCode, 36)
        XCTAssertEqual(decoded.control, false)
        XCTAssertEqual(decoded.command, true)
        XCTAssertEqual(decoded.interKeyDelay, 20000)
        XCTAssertEqual(decoded.batchSize, 5)
    }
}
