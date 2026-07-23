import Cocoa
import Carbon
import OSLog

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var currentConfig: AppConfig = loadConfig()
    var hotkeyMenuItem: NSMenuItem!
    var memoryMenuItem: NSMenuItem!
    var menuMemoryMonitor = MemoryMonitor()
    // debugWindow is held separately because it's a singleton (reopen shows existing).
    // activeWindow is for transient windows (speed settings, hotkey recorder) — one at a time.
    var debugWindow: DebugWindow?
    var activeWindow: ManagedWindow?
    let typingEngine = TypingEngine()
    private var eventHandlerInstalled = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.app.notice("Application launching")
        // Request notification permission once at launch (not on every send).
        NotificationManager.shared.requestAuthorization()
        checkAccessibilityPermission()
        
        // SF Symbol "keyboard" as template image adapts to light/dark mode automatically.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ClipboardTyper") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⌨️"
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "ClipboardTyper v2", action: nil, keyEquivalent: ""))
        
        hotkeyMenuItem = NSMenuItem(title: L10n.hotkey + currentConfig.displayString, action: nil, keyEquivalent: "")
        menu.addItem(hotkeyMenuItem)
        
        // Memory display: updates every 2s while menu is open via NSMenuDelegate.
        memoryMenuItem = NSMenuItem(title: "Memory: --", action: nil, keyEquivalent: "")
        memoryMenuItem.isEnabled = false
        menu.addItem(memoryMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.changeHotKey, action: #selector(changeHotKey), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.speedSettings, action: #selector(showSpeedSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.debugMenuTitle, action: #selector(showDebugWindow), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        menu.delegate = self
        
        updateLaunchAtLoginMenuItem()
        registerHotKey()
        
        sendNotification(title: L10n.appName, body: L10n.launched + currentConfig.displayString)
    }
    
    // MARK: - Hot Key Registration
    
    func registerHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4354_4B59)  // "CTKY" — arbitrary unique 4-char code
        hotKeyID.id = 1
        
        Logger.hotkey.debug("Registering hotkey: keyCode=\(self.currentConfig.keyCode), carbonMods=0x\(String(self.currentConfig.carbonModifiers, radix: 16)), display=\(self.currentConfig.displayString)")
        
        let status = RegisterEventHotKey(
            currentConfig.keyCode,
            currentConfig.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            Logger.hotkey.error("Hotkey registration failed with status: \(status)")
            sendNotification(title: L10n.appName, body: L10n.hotkeyRegisterFailed(status))
            return
        }
        
        Logger.hotkey.notice("Hotkey registered successfully: \(self.currentConfig.displayString)")
        
        // The event handler only needs to be installed once — it persists across
        // hotkey re-registrations. Multiple installs would create duplicate handlers.
        if !eventHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, nil)
            eventHandlerInstalled = true
        }
    }
    
    // MARK: - Window Actions
    
    @objc func changeHotKey() {
        // Unregister hotkey while recording to prevent the current hotkey
        // from triggering typing when the user presses it to re-bind.
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        let window = HotKeyRecorderWindow(currentConfig: currentConfig) { [weak self] newConfig in
            guard let self = self else { return }
            self.currentConfig.keyCode = newConfig.keyCode
            self.currentConfig.control = newConfig.control
            self.currentConfig.option = newConfig.option
            self.currentConfig.shift = newConfig.shift
            self.currentConfig.command = newConfig.command
            saveConfig(self.currentConfig)
            self.registerHotKey()
            self.hotkeyMenuItem.title = L10n.hotkey + self.currentConfig.displayString
            sendNotification(title: L10n.appName, body: L10n.hotkeyUpdated(self.currentConfig.displayString))
        }
        // activeWindow holds a strong reference so the window isn't deallocated immediately.
        // onClose nils it when the window closes, allowing ARC to reclaim memory.
        // Also re-registers the hotkey if the user cancelled without confirming.
        window.onClose = { [weak self] in
            self?.activeWindow = nil
            // Re-register hotkey if it wasn't already re-registered by the confirm callback.
            if self?.hotKeyRef == nil {
                self?.registerHotKey()
            }
        }
        activeWindow = window
        window.showWindow()
    }
    
    @objc func showSpeedSettings() {
        let window = SpeedSettingsWindow(config: currentConfig) { [weak self] updatedConfig in
            guard let self = self else { return }
            self.currentConfig = updatedConfig
            saveConfig(updatedConfig)
            sendNotification(title: L10n.appName, body: L10n.speedUpdated)
        }
        window.onClose = { [weak self] in self?.activeWindow = nil }
        activeWindow = window
        window.showWindow()
    }
    
    @objc func showDebugWindow() {
        // Singleton pattern: only one debug window at a time.
        if debugWindow == nil {
            debugWindow = DebugWindow { [weak self] in
                self?.debugWindow = nil
            }
        }
        debugWindow?.showWindow()
    }
    
    // MARK: - Launch at Login
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.hche608.ClipboardTyper.plist")
        
        if FileManager.default.fileExists(atPath: plistPath.path) {
            try? FileManager.default.removeItem(at: plistPath)
            sender.state = .off
            sendNotification(title: L10n.appName, body: L10n.launchAtLoginDisabled)
        } else {
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.hche608.ClipboardTyper</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/Applications/ClipboardTyper.app/Contents/MacOS/ClipboardTyper</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            let dir = plistPath.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? plist.write(to: plistPath, atomically: true, encoding: .utf8)
            sender.state = .on
            sendNotification(title: L10n.appName, body: L10n.launchAtLoginEnabled)
        }
    }
    
    func updateLaunchAtLoginMenuItem() {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.hche608.ClipboardTyper.plist")
        if let menu = statusItem.menu,
           let item = menu.items.first(where: { $0.title == L10n.launchAtLogin }) {
            item.state = FileManager.default.fileExists(atPath: plistPath.path) ? .on : .off
        }
    }
    
    // MARK: - Accessibility
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            let alert = NSAlert()
            alert.messageText = L10n.permissionTitle
            alert.informativeText = L10n.permissionMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.openSettings)
            alert.addButton(withTitle: L10n.quitButton)
            
            // Manually draw rounded corners on app icon for the alert.
            // NSAlert doesn't auto-clip to macOS icon shape for custom icons.
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let icon = NSImage(contentsOfFile: iconPath) {
                let size = NSSize(width: 128, height: 128)
                let rounded = NSImage(size: size)
                rounded.lockFocus()
                let rect = NSRect(origin: .zero, size: size)
                let path = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
                path.addClip()
                icon.draw(in: rect)
                rounded.unlockFocus()
                alert.icon = rounded
            }
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
                waitForAccessibility()
            } else {
                NSApp.terminate(nil)
            }
        }
    }
    
    /// Polls AXIsProcessTrusted() every second for up to 2 minutes.
    /// Once granted, registers the hotkey and sends launch notification.
    func waitForAccessibility() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for _ in 0..<120 {
                sleep(1)
                if AXIsProcessTrusted() {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        Logger.app.notice("Accessibility permission granted")
                        self.registerHotKey()
                        sendNotification(title: L10n.appName, body: L10n.launched + self.currentConfig.displayString)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                Logger.app.warning("Accessibility permission timeout after 120s")
                sendNotification(title: L10n.appName, body: L10n.permissionTimeout)
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    // Start memory monitoring only while the menu is visible — no wasted resources when closed.
    func menuWillOpen(_ menu: NSMenu) {
        menuMemoryMonitor.start { [weak self] formatted in
            self?.memoryMenuItem.title = "Memory: \(formatted)"
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuMemoryMonitor.stop()
    }
}

// MARK: - Hot Key Handler

// C-style callback required by Carbon RegisterEventHotKey API.
// Must be a free function (not a method) because Carbon doesn't support closures.
// Reads clipboard on main thread (where this handler fires), then dispatches
// typing to background to avoid blocking the main run loop.
func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let delegate = NSApp.delegate as? AppDelegate else { return noErr }
    let config = delegate.currentConfig
    let engine = delegate.typingEngine
    // Read clipboard on main thread — NSPasteboard is not documented as thread-safe.
    // Also avoids timing issues where clipboard changes between trigger and read.
    let clipboard = NSPasteboard.general.string(forType: .string)
    Logger.hotkey.debug("Hotkey triggered, clipboard has \(clipboard?.count ?? 0) chars, dispatching typing engine")
    DispatchQueue.global(qos: .userInitiated).async {
        engine.perform(config: config, text: clipboard)
    }
    return noErr
}
