import Cocoa

// MARK: - Managed Window Base Class

// Community best practice for LSUIElement menu bar apps:
//
// Problem: isReleasedWhenClosed=true causes macOS to terminate the app when the
// last window closes (because LSUIElement apps have no persistent window).
//
// Solution:
// - isReleasedWhenClosed = false: prevents system from releasing/terminating
// - NSWindowDelegate.windowWillClose: our cleanup hook
// - delegate = nil: breaks the self→delegate→self retain cycle
// - contentView = nil: releases all subviews (the real memory, ~30MB for Debug window)
// - async onClose: lets the caller nil its reference AFTER close() stack unwinds,
//   preventing use-after-free crashes
//
// The window shell (~1KB) stays in NSApp.windows until ARC collects it.
// Verified: purge shows memory correctly returns to baseline.

class ManagedWindow: NSWindow, NSWindowDelegate {
    var onClose: (() -> Void)?
    
    init(size: NSSize, title: String, styleMask: NSWindow.StyleMask = [.titled, .closable], floating: Bool = true, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        let rect = NSRect(origin: .zero, size: size)
        super.init(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        
        self.title = title
        self.center()
        self.isReleasedWhenClosed = false
        self.delegate = self
        if floating {
            self.level = .floating
        }
    }
    
    /// Override in subclasses to release non-UI resources (event monitors, timers, callbacks).
    /// UI elements are released by contentView = nil in windowWillClose — no need to nil them individually.
    func releaseResources() {}
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        releaseResources()
        self.delegate = nil
        self.contentView = nil
        // Async: ensures NSWindow's internal close() stack fully unwinds before
        // the external reference is nilled (which may dealloc self).
        DispatchQueue.main.async { [weak self] in
            self?.onClose?()
            self?.onClose = nil
        }
    }
    
    func showWindow() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
