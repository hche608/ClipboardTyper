import Cocoa

// Entry point. We use NSApplication directly (no NSApplicationMain) because
// this is a menu bar-only app with no main window or storyboard.
// .accessory policy hides the app from Dock and Cmd+Tab switcher.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
