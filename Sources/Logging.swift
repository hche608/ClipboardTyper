import OSLog

// MARK: - Logger Instances

// One logger per functional area for precise filtering in Console.app and `log` CLI.
// Subsystem = reverse-DNS app id; category = functional area.
// Levels: .debug/.info are non-persisted (dev-only); .notice+ survives reboots.
extension Logger {
    private static let subsystem = "com.hche608.ClipboardTyper"
    
    /// General app lifecycle events (launch, permissions, config changes)
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// Typing engine operations (start, finish, skipped chars)
    static let typing = Logger(subsystem: subsystem, category: "typing")
    
    /// Hotkey registration and triggering
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
