import Cocoa

// MARK: - Hot Key Recorder Window

class HotKeyRecorderWindow: ManagedWindow {
    var recordedConfig: HotKeyConfig?
    var onConfirm: ((HotKeyConfig) -> Void)?
    var displayLabel: NSTextField!
    var hintLabel: NSTextField!
    var confirmButton: NSButton!
    var clearButton: NSButton!
    var cancelButton: NSButton!
    var eventMonitor: Any?
    var globalMonitor: Any?
    var isRecording: Bool = true
    
    init(currentConfig: AppConfig, onConfirm: @escaping (HotKeyConfig) -> Void) {
        self.onConfirm = onConfirm
        
        super.init(size: NSSize(width: 360, height: 180), title: L10n.changeHotKeyTitle)
        
        let rect = NSRect(x: 0, y: 0, width: 360, height: 180)
        let contentView = NSView(frame: rect)
        
        hintLabel = NSTextField(labelWithString: L10n.pressHotKey)
        hintLabel.frame = NSRect(x: 20, y: 140, width: 320, height: 20)
        hintLabel.alignment = .center
        hintLabel.font = NSFont.systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabelColor
        contentView.addSubview(hintLabel)
        
        let currentLabel = NSTextField(labelWithString: L10n.currentHotKey + currentConfig.displayString)
        currentLabel.frame = NSRect(x: 20, y: 115, width: 320, height: 18)
        currentLabel.alignment = .center
        currentLabel.font = NSFont.systemFont(ofSize: 11)
        currentLabel.textColor = .tertiaryLabelColor
        contentView.addSubview(currentLabel)
        
        displayLabel = NSTextField(labelWithString: L10n.waitingForInput)
        displayLabel.frame = NSRect(x: 40, y: 65, width: 280, height: 40)
        displayLabel.alignment = .center
        displayLabel.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .medium)
        displayLabel.isBezeled = true
        displayLabel.bezelStyle = .roundedBezel
        displayLabel.backgroundColor = NSColor.controlBackgroundColor
        contentView.addSubview(displayLabel)
        
        confirmButton = NSButton(title: L10n.confirm, target: self, action: #selector(confirmPressed))
        confirmButton.frame = NSRect(x: 240, y: 15, width: 80, height: 32)
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        confirmButton.isEnabled = false
        contentView.addSubview(confirmButton)
        
        clearButton = NSButton(title: L10n.reRecord, target: self, action: #selector(clearPressed))
        clearButton.frame = NSRect(x: 140, y: 15, width: 80, height: 32)
        clearButton.bezelStyle = .rounded
        clearButton.isHidden = true
        contentView.addSubview(clearButton)
        
        cancelButton = NSButton(title: L10n.cancel, target: self, action: #selector(cancelPressed))
        cancelButton.frame = NSRect(x: 40, y: 15, width: 80, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
        
        self.contentView = contentView
        
        startMonitoring()
    }
    
    override func releaseResources() {
        stopMonitoring()
        onConfirm = nil
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        isRecording = true
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = event.keyCode
            
            if event.type == .flagsChanged {
                if !flags.isEmpty {
                    self.displayLabel.stringValue = self.modifiersToString(flags) + "..."
                    self.displayLabel.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .medium)
                    self.displayLabel.textColor = .secondaryLabelColor
                } else {
                    self.displayLabel.stringValue = L10n.waitingForInput
                    self.displayLabel.textColor = .placeholderTextColor
                }
                self.confirmButton.isEnabled = false
                self.recordedConfig = nil
                return nil
            }
            
            let isFunctionKey = (keyCode >= 96 && keyCode <= 122) || keyCode == 118 || keyCode == 120
            if flags.isEmpty && !isFunctionKey { return nil }
            if keyCode == 53 && flags.isEmpty { self.cancelPressed(); return nil }
            
            if self.recordedConfig == nil {
                self.recordHotKey(keyCode: keyCode, flags: flags)
            }
            return nil
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self, self.isRecording else { return }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = event.keyCode
            
            let isFunctionKey = (keyCode >= 96 && keyCode <= 122) || keyCode == 118 || keyCode == 120
            if flags.isEmpty && !isFunctionKey { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.recordedConfig == nil else { return }
                self.recordHotKey(keyCode: keyCode, flags: flags)
            }
        }
    }
    
    func recordHotKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        let config = HotKeyConfig(
            keyCode: UInt32(keyCode),
            control: flags.contains(.control),
            option: flags.contains(.option),
            shift: flags.contains(.shift),
            command: flags.contains(.command)
        )
        
        self.recordedConfig = config
        self.isRecording = false
        self.displayLabel.stringValue = config.displayString
        self.displayLabel.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .bold)
        self.displayLabel.textColor = .labelColor
        self.confirmButton.isEnabled = true
        self.clearButton.isHidden = false
        self.hintLabel.stringValue = L10n.hotkeyRecorded
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    func modifiersToString(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }
    
    // MARK: - Actions
    
    @objc func confirmPressed() {
        if let config = recordedConfig {
            onConfirm?(config)
        }
        close()
    }
    
    @objc func clearPressed() {
        recordedConfig = nil
        confirmButton.isEnabled = false
        clearButton.isHidden = true
        displayLabel.stringValue = L10n.waitingForInput
        displayLabel.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .medium)
        displayLabel.textColor = .placeholderTextColor
        hintLabel.stringValue = L10n.pressHotKey
        isRecording = true
    }
    
    @objc func cancelPressed() {
        close()
    }
}
