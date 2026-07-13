import Foundation
import CoreGraphics
import Carbon
import OSLog

// MARK: - Typing Engine

// Why NSAppleScript + System Events `key code`:
// - RDP client only forwards IOHIDSystem-level key events to remote Windows
// - System Events injects at IOHIDSystem layer (same as physical keyboard)
// - CGEvent.post() injects at WindowServer layer — RDP ignores its Shift flags
// - keyboardSetUnicodeString doesn't work — RDP only reads keyCode, not unicode
//
// Why NSAppleScript over ScriptingBridge or raw AppleEvents:
// - `key code {list} using {shift down}` batch syntax is only natively supported
//   by AppleScript. Other approaches require manually constructing AE descriptors.
// - ~5ms overhead per call is acceptable for our use case.
//
// Why batch consecutive same-shift chars:
// - Reduces number of NSAppleScript invocations (the bottleneck)
// - Single `key code {list}` sends atomically — no risk of interleaved Shift changes
// - Avoids triggering Sticky Keys or multi-Shift shortcuts on remote

class TypingEngine {
    private var batch: [(CGKeyCode, Bool)] = []
    private var batchShift: Bool? = nil
    
    /// Re-entry guard: prevents concurrent perform() calls from racing on batch state.
    /// Protected by lock because perform() is called from DispatchQueue.global().
    private var isRunning = false
    private let lock = NSLock()
    
    /// Notification callback — injectable for testing.
    /// Defaults to the real sendNotification function; tests can replace with a no-op.
    var notify: (_ title: String, _ body: String) -> Void = sendNotification
    
    /// Performs typing of the given text using the in-memory config.
    /// `text` should be read from NSPasteboard on the main thread before dispatching here.
    func perform(config: AppConfig, text: String?) {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            Logger.typing.warning("Typing already in progress, ignoring hotkey trigger")
            notify(L10n.appName, L10n.alreadyTyping)
            return
        }
        isRunning = true
        lock.unlock()
        defer { lock.withLock { isRunning = false } }
        guard let text = text, !text.isEmpty else {
            Logger.typing.notice("Clipboard empty, nothing to type")
            notify(L10n.appName, L10n.clipboardEmpty)
            return
        }
        
        let charTotal = text.count
        Logger.typing.notice("Starting typing: \(charTotal) chars, batch=\(config.batchSize), chunk=\(config.chunkSize)")
        notify(L10n.appName, L10n.typingStarted(charTotal))
        
        // Wait for hotkey modifier keys to be physically released.
        // Without this, the first few characters get Ctrl/Option applied.
        usleep(300_000)
        
        var charCount = 0
        var skippedCount = 0
        batch.removeAll(keepingCapacity: true)
        batchShift = nil
        
        for char in text {
            autoreleasepool {
                if char == "\n" || char == "\r" {
                    flush(shift: batchShift ?? false, delay: config.interKeyDelay)
                    batchShift = nil
                    Self.executeKeyCode(36)  // Return key
                    usleep(config.interKeyDelay)
                } else if char == "\t" {
                    flush(shift: batchShift ?? false, delay: config.interKeyDelay)
                    batchShift = nil
                    Self.executeKeyCode(48)  // Tab key
                    usleep(config.interKeyDelay)
                } else if let (keyCode, shift) = charToKeyCode(char) {
                    // Flush when shift state changes — can't mix shifted/unshifted in one batch
                    if batchShift != nil && batchShift != shift {
                        flush(shift: batchShift!, delay: config.interKeyDelay)
                    }
                    batchShift = shift
                    batch.append((keyCode, shift))
                    
                    if batch.count >= config.batchSize {
                        flush(shift: batchShift!, delay: config.interKeyDelay)
                        batchShift = nil
                    }
                } else {
                    // Non-ASCII chars (Chinese, emoji) can't be mapped to key codes.
                    // Skip silently and report count at the end.
                    skippedCount += 1
                }
                
                charCount += 1
                
                // Extra pause every chunkSize chars to let RDP protocol catch up
                if charCount % config.chunkSize == 0 {
                    flush(shift: batchShift ?? false, delay: config.interKeyDelay)
                    batchShift = nil
                    usleep(config.interChunkDelay)
                }
            }
        }
        
        if !batch.isEmpty {
            flush(shift: batchShift ?? false, delay: config.interKeyDelay)
        }
        
        if skippedCount > 0 {
            Logger.typing.notice("Typing complete: \(charCount) chars, \(skippedCount) skipped")
            notify(L10n.appName, L10n.typingDoneWithSkipped(charCount, skippedCount))
        } else {
            Logger.typing.notice("Typing complete: \(charCount) chars")
            notify(L10n.appName, L10n.typingDone(charCount))
        }
    }
    
    // MARK: - Private
    
    /// Sends all accumulated key codes as a single AppleScript call.
    /// autoreleasepool wraps NSAppleScript to mitigate known Apple memory leaks.
    /// removeAll(keepingCapacity: true) reuses the array allocation across batches.
    private func flush(shift: Bool, delay: UInt32) {
        guard !batch.isEmpty else { return }
        
        autoreleasepool {
            let codes = batch.map { String($0.0) }.joined(separator: ", ")
            let script: String
            if shift {
                script = "tell application \"System Events\" to key code {\(codes)} using {shift down}"
            } else {
                script = "tell application \"System Events\" to key code {\(codes)}"
            }
            
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        }
        usleep(delay)
        
        batch.removeAll(keepingCapacity: true)
    }
    
    /// Single key code execution for special keys (Return, Tab) that must be sent alone.
    private static func executeKeyCode(_ keyCode: Int, shift: Bool = false) {
        autoreleasepool {
            let script: String
            if shift {
                script = "tell application \"System Events\" to key code \(keyCode) using {shift down}"
            } else {
                script = "tell application \"System Events\" to key code \(keyCode)"
            }
            
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        }
    }
}
