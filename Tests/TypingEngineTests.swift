import XCTest
import Foundation
@preconcurrency @testable import ClipboardTyper

// MARK: - Typing Engine Tests

final class TypingEngineTests: XCTestCase {
    func testPerformNilTextDoesNotCrash() {
        let engine = TypingEngine()
        let config = AppConfig.defaultConfig
        // Should not crash; just returns after sending "clipboard empty" notification
        engine.perform(config: config, text: nil)
    }

    func testPerformEmptyTextDoesNotCrash() {
        let engine = TypingEngine()
        let config = AppConfig.defaultConfig
        engine.perform(config: config, text: "")
    }

    func testReentryGuardPreventsConccurrentExecution() {
        let engine = TypingEngine()
        var config = AppConfig.defaultConfig
        // Use minimal delays
        config.interKeyDelay = 1000
        config.interChunkDelay = 1000
        config.batchSize = 50
        config.chunkSize = 1000

        let expectation = XCTestExpectation(description: "First perform completes")
        let configCopy = config

        // Start a typing operation on background thread
        let workItem = DispatchWorkItem {
            engine.perform(config: configCopy, text: "hello world")
            expectation.fulfill()
        }
        DispatchQueue.global().async(execute: workItem)

        // Give it a moment to acquire the lock
        usleep(50_000)

        // This second call should be rejected by the re-entry guard (not crash or deadlock)
        engine.perform(config: configCopy, text: "second call")

        wait(for: [expectation], timeout: 10.0)
    }
}
