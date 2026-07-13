import XCTest
import Foundation
@preconcurrency @testable import ClipboardTyper

// MARK: - Typing Engine Tests

final class TypingEngineTests: XCTestCase {
    /// Creates a TypingEngine with notifications disabled (avoids UNUserNotificationCenter crash in test runner).
    private func makeEngine() -> TypingEngine {
        let engine = TypingEngine()
        engine.notify = { _, _ in }  // no-op
        return engine
    }

    func testPerformNilTextDoesNotCrash() {
        let engine = makeEngine()
        let config = AppConfig.defaultConfig
        engine.perform(config: config, text: nil)
    }

    func testPerformEmptyTextDoesNotCrash() {
        let engine = makeEngine()
        let config = AppConfig.defaultConfig
        engine.perform(config: config, text: "")
    }

    func testReentryGuardPreventsConccurrentExecution() {
        let engine = makeEngine()
        var config = AppConfig.defaultConfig
        config.interKeyDelay = 1000
        config.interChunkDelay = 1000
        config.batchSize = 50
        config.chunkSize = 1000

        let expectation = XCTestExpectation(description: "First perform completes")
        let configCopy = config

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
