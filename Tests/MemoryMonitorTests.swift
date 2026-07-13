import XCTest
@testable import ClipboardTyper

// MARK: - Memory Monitor Tests

final class MemoryMonitorTests: XCTestCase {
    func testResidentBytesNonZero() {
        let bytes = MemoryMonitor.residentBytes()
        XCTAssertGreaterThan(bytes, 0, "Process should have some resident memory")
    }

    func testFormattedMemoryReportsMB() {
        let formatted = MemoryMonitor.formattedMemory()
        // A running test process will always be > 1MB
        XCTAssertTrue(formatted.contains("MB"), "Test process should report MB, got: \(formatted)")
    }

    func testResidentBytesIsReasonable() {
        let bytes = MemoryMonitor.residentBytes()
        let oneMB: UInt64 = 1_048_576
        let twoGB: UInt64 = 2 * 1_073_741_824
        XCTAssertGreaterThanOrEqual(bytes, oneMB, "Should be at least 1MB")
        XCTAssertLessThanOrEqual(bytes, twoGB, "Should be less than 2GB for a test process")
    }
}
