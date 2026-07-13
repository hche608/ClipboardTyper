import Cocoa

// MARK: - Debug Window

// Real-time keyboard event monitor + memory tracker.
// Why this exists: to diagnose which key events are being generated/captured,
// and to verify memory is properly released after window close.
// The window is floating (always on top) so it stays visible while testing in other apps.

class DebugWindow: ManagedWindow {
    var textView: NSTextView!
    var localMonitor: Any?
    var globalMonitor: Any?
    var memoryLabel: NSTextField!
    var memoryMonitor = MemoryMonitor()
    
    var toggleButton: NSButton!
    var clearButton: NSButton!
    var copyButton: NSButton!
    var isMonitoring = false
    
    private static let maxLogLines = 1000
    private var lineCount = 0
    private lazy var timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    init(onClose: @escaping () -> Void) {
        super.init(
            size: NSSize(width: 600, height: 400),
            title: L10n.debugMonitoring,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            onClose: onClose
        )
        
        let rect = NSRect(x: 0, y: 0, width: 600, height: 400)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 70, width: 600, height: 330))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        
        // Memory label
        memoryLabel = NSTextField(labelWithString: "Memory: --")
        memoryLabel.frame = NSRect(x: 10, y: 40, width: 580, height: 20)
        memoryLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        memoryLabel.textColor = .secondaryLabelColor
        memoryLabel.autoresizingMask = [.width]
        
        // Buttons: Toggle | Clear | Copy Log
        toggleButton = NSButton(title: L10n.debugToggleStop, target: self, action: #selector(toggleMonitoring))
        toggleButton.frame = NSRect(x: 10, y: 5, width: 100, height: 30)
        toggleButton.bezelStyle = .rounded
        
        clearButton = NSButton(title: L10n.debugClear, target: self, action: #selector(clearLog))
        clearButton.frame = NSRect(x: 120, y: 5, width: 80, height: 30)
        clearButton.bezelStyle = .rounded
        clearButton.isEnabled = false
        
        copyButton = NSButton(title: L10n.debugCopyLog, target: self, action: #selector(copyLog))
        copyButton.frame = NSRect(x: 210, y: 5, width: 100, height: 30)
        copyButton.bezelStyle = .rounded
        copyButton.isEnabled = false
        
        let contentView = NSView(frame: rect)
        contentView.addSubview(scrollView)
        contentView.addSubview(memoryLabel)
        contentView.addSubview(toggleButton)
        contentView.addSubview(clearButton)
        contentView.addSubview(copyButton)
        self.contentView = contentView
        
        startMonitoring()
        // MemoryMonitor timer fires on main RunLoop (.common mode), no need for DispatchQueue.main.
        memoryMonitor.start { [weak self] formatted in
            self?.memoryLabel?.stringValue = "Memory: \(formatted) (resident)"
        }
    }
    
    override func releaseResources() {
        stopMonitoring()
        memoryMonitor.stop()
    }
    
    // MARK: - Monitoring Control
    
    @objc func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        stopMonitoringInternal()
        isMonitoring = true
        updateToggleButton()
        log("--- Monitoring started ---")
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event, source: "LOCAL")
            return event
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event, source: "GLOBAL")
        }
    }
    
    func stopMonitoring() {
        stopMonitoringInternal()
        isMonitoring = false
        updateToggleButton()
        log("--- Monitoring stopped ---")
    }
    
    private func stopMonitoringInternal() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }
    
    private func updateToggleButton() {
        if isMonitoring {
            toggleButton?.title = L10n.debugToggleStop
            self.title = L10n.debugMonitoring
        } else {
            toggleButton?.title = L10n.debugToggleStart
            self.title = L10n.debugStopped
        }
    }
    
    // MARK: - Event Handling
    
    func handleEvent(_ event: NSEvent, source: String) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        let eventType: String
        switch event.type {
        case .keyDown: eventType = "keyDown"
        case .keyUp: eventType = "keyUp"
        case .flagsChanged: eventType = "flagsChanged"
        default: eventType = "other(\(event.type.rawValue))"
        }
        
        let modsStr = flagsToString(flags)
        let chars = event.type == .flagsChanged ? "-" : (event.characters ?? "nil")
        let charsIgnoring = event.type == .flagsChanged ? "-" : (event.charactersIgnoringModifiers ?? "nil")
        let translated = keyCodeToString(UInt32(keyCode))
        
        let line = "[\(source)] \(eventType) | keyCode: \(keyCode) | mods: \(modsStr) | chars: \"\(chars)\" | charsIgnoring: \"\(charsIgnoring)\" | translated: \"\(translated)\""
        log(line)
    }
    
    func flagsToString(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        if flags.contains(.capsLock) { s += "⇪" }
        if flags.contains(.function) { s += "fn" }
        return s.isEmpty ? "(none)" : s
    }
    
    // MARK: - Log
    
    /// Appends a timestamped line to the debug log.
    /// Uses NSTextStorage.append for O(1) append instead of string += which is O(n).
    /// Trims from the front using character range deletion to avoid O(n) string splitting.
    func log(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textView = self.textView, let storage = textView.textStorage else { return }
            let timestamp = self.timestampFormatter.string(from: Date())
            let line = "[\(timestamp)] \(text)\n"
            let attributed = NSAttributedString(string: line, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ])
            storage.append(attributed)
            self.lineCount += 1
            self.trimLogIfNeeded()
            textView.scrollToEndOfDocument(nil)
            self.updateActionButtons()
        }
    }
    
    private func trimLogIfNeeded() {
        guard let storage = textView?.textStorage, self.lineCount > Self.maxLogLines else { return }
        // Remove the oldest 20% to avoid trimming on every single line
        let linesToRemove = Self.maxLogLines / 5
        let string = storage.string
        var removeEnd = string.startIndex
        var removed = 0
        for char in string {
            removeEnd = string.index(after: removeEnd)
            if char == "\n" {
                removed += 1
                if removed >= linesToRemove { break }
            }
        }
        let charRange = NSRange(string.startIndex..<removeEnd, in: string)
        storage.deleteCharacters(in: charRange)
        self.lineCount -= removed
    }
    
    private func updateActionButtons() {
        let hasContent = !(textView?.string.isEmpty ?? true)
        clearButton?.isEnabled = hasContent
        copyButton?.isEnabled = hasContent
    }
    
    @objc func clearLog() {
        textView?.string = ""
        lineCount = 0
        updateActionButtons()
    }
    
    @objc func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView?.string ?? "", forType: .string)
        log("--- Log copied to clipboard ---")
    }
}
