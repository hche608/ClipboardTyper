import Foundation

// MARK: - Memory Monitor

// Reusable timer-based memory reporter. Used in both the menu bar dropdown
// and the Debug window. Each creates its own instance — they don't interfere.
// Why mach_task_basic_info: it's the only way to get process resident memory
// without shelling out to `ps` or `top`.
class MemoryMonitor {
    private var timer: Timer?
    private var onUpdate: ((String) -> Void)?
    
    /// Starts periodic reporting. Calls onUpdate immediately, then every `interval` seconds.
    /// Calling start() again automatically stops the previous timer.
    /// Timer is explicitly added to the main RunLoop in `.common` mode so it fires
    /// even during menu tracking (which suspends the default mode).
    func start(interval: TimeInterval = 2.0, onUpdate: @escaping (String) -> Void) {
        stop()
        self.onUpdate = onUpdate
        onUpdate(Self.formattedMemory())
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.onUpdate?(Self.formattedMemory())
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    /// Stops the timer and releases the callback closure (important for preventing retain cycles).
    func stop() {
        timer?.invalidate()
        timer = nil
        onUpdate = nil
    }
    
    static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    static func formattedMemory() -> String {
        let bytes = residentBytes()
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f KB", Double(bytes) / 1024.0)
    }
}
