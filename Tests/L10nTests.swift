import XCTest
@testable import ClipboardTyper

// MARK: - Localization Tests

final class L10nTests: XCTestCase {
    func testAppNameIsConstant() {
        XCTAssertEqual(L10n.appName, "ClipboardTyper")
    }

    func testTypingStartedIncludesCount() {
        let result = L10n.typingStarted(42)
        XCTAssertTrue(result.contains("42"), "typingStarted should include the character count")
    }

    func testTypingDoneIncludesCount() {
        let result = L10n.typingDone(100)
        XCTAssertTrue(result.contains("100"), "typingDone should include the character count")
    }

    func testTypingDoneWithSkippedIncludesBothCounts() {
        let result = L10n.typingDoneWithSkipped(500, 12)
        XCTAssertTrue(result.contains("500"), "Should include typed count")
        XCTAssertTrue(result.contains("12"), "Should include skipped count")
    }

    func testHotkeyUpdatedIncludesKey() {
        let result = L10n.hotkeyUpdated("⌃⌥V")
        XCTAssertTrue(result.contains("⌃⌥V"), "hotkeyUpdated should include the key string")
    }

    func testHotkeyRegisterFailedIncludesCode() {
        let result = L10n.hotkeyRegisterFailed(-9878)
        XCTAssertTrue(result.contains("-9878"), "hotkeyRegisterFailed should include the status code")
    }

    func testEstimateSpeedIncludesCPS() {
        let result = L10n.estimateSpeed(350)
        XCTAssertTrue(result.contains("350"), "estimateSpeed should include the chars/sec value")
    }
}
