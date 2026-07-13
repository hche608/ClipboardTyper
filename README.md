# ClipboardTyper

[![CI](https://github.com/hche608/ClipboardTyper/actions/workflows/ci.yml/badge.svg)](https://github.com/hche608/ClipboardTyper/actions/workflows/ci.yml)

Type clipboard content as physical keystrokes on macOS — works over RDP where paste is disabled.

## What it does

ClipboardTyper is a macOS menu bar app that reads your clipboard and simulates real keyboard input using System Events `key code` injection at the IOHIDSystem layer. RDP clients forward these events identically to physical keystrokes, bypassing clipboard paste restrictions.

## Requirements

- macOS 14+
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Install

```bash
git clone git@github.com:hche608/ClipboardTyper.git
cd ClipboardTyper
chmod +x build.sh
./build.sh --install
```

The build script produces a proper `.app` bundle at `dist/ClipboardTyper.app`. Pass `--install` to deploy to `/Applications` and launch immediately, or manually copy:

```bash
cp -R dist/ClipboardTyper.app /Applications/
```

## Usage

1. Copy text to clipboard
2. Focus the target input field (local or remote desktop)
3. Press hotkey `⌃⌥V` (customizable)
4. ClipboardTyper types it out character by character

## Features

- ⌨️ Global hotkey trigger (default ⌃⌥V, customizable)
- 🎯 Hotkey recorder (press-to-record, not checkbox)
- 🌐 Bilingual UI (Chinese/English, follows system)
- 🔔 Native notifications with app icon
- ⚡ Speed presets (Fast / Balanced / Safe)
- 🛡 Batch key code sending to avoid Sticky Keys
- 🐛 Debug window (event monitor + memory tracker)
- 🚀 Launch at Login (LaunchAgent)
- 📊 Structured logging via OSLog (filterable in Console.app)

## How it works

```
Clipboard → charToKeyCode mapping (US QWERTY)
         → Batch same-shift chars into one AppleScript call
         → System Events `key code {list} using {shift down}`
         → IOHIDSystem layer injection
         → RDP client forwards as physical scancodes
         → Remote Windows receives correct input
```

## App Bundle Structure

```
ClipboardTyper.app/
└── Contents/
    ├── Info.plist          (LSUIElement, CFBundleIconFile, bundle ID)
    ├── PkgInfo             (APPL???? marker)
    ├── MacOS/
    │   └── ClipboardTyper  (arm64 Mach-O binary)
    └── Resources/
        ├── AppIcon.icns    (app icon for Finder/Dock)
        └── AppIcon.png     (fallback for notifications)
```

## Source Structure

```
Sources/
├── main.swift                  # Entry point, NSApplication.accessory policy
├── AppDelegate.swift           # Menu bar, hotkey registration, window management
├── TypingEngine.swift          # Core: batch System Events key code injection
├── Config.swift                # AppConfig persistence (~/.config/ClipboardTyper/)
├── KeyMapping.swift            # US QWERTY char→keyCode table + UCKeyTranslate
├── ManagedWindow.swift         # Window base class for LSUIElement lifecycle
├── HotKeyRecorderWindow.swift  # Press-to-record hotkey customization
├── SpeedSettingsWindow.swift   # Slider-based speed tuning with presets
├── DebugWindow.swift           # Real-time event monitor + memory tracker
├── MemoryMonitor.swift         # mach_task_basic_info resident memory reporter
├── Notification.swift          # UNUserNotificationCenter wrapper
├── Logging.swift               # OSLog Logger instances (app/typing/hotkey)
└── L10n.swift                  # Bilingual Chinese/English UI strings
```

## Configuration

Stored at `~/.config/ClipboardTyper/config.json`:

```json
{
  "keyCode": 9,
  "control": true,
  "option": true,
  "shift": false,
  "command": false,
  "interKeyDelay": 5000,
  "interChunkDelay": 10000,
  "chunkSize": 100,
  "batchSize": 10
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `interKeyDelay` | 5000 μs (5ms) | Delay between batches |
| `interChunkDelay` | 10000 μs (10ms) | Extra pause every `chunkSize` chars |
| `chunkSize` | 100 | Characters before extra pause |
| `batchSize` | 10 | Characters per AppleScript call |

## Why System Events key code?

| Layer | API | RDP Compatibility |
|-------|-----|-------------------|
| IOHIDSystem (kernel) | System Events `key code` | ✅ Indistinguishable from physical keyboard |
| WindowServer | CGEvent.post() | ❌ RDP ignores Shift modifier flags |

CGEvent posts at the WindowServer layer. Microsoft Remote Desktop ignores CGEvent's Shift modifier flags — all characters arrive as lowercase on the remote side. System Events injects at IOHIDSystem (kernel level), which RDP cannot distinguish from a real keyboard.

## Why not CGEvent?

Two approaches were tested and failed:

1. **CGEvent + Shift flagsChanged**: Remote RDP shows all lowercase. RDP client queries hardware modifier state, doesn't trust CGEvent flags.
2. **CGEvent + keyboardSetUnicodeString**: Remote shows all "a". RDP only reads keyCode (scan code), ignores unicode string.

See `PasteSimulator-v2.md` for detailed technical analysis.

## Known limitations

- US QWERTY layout only — non-ASCII characters (Chinese, emoji) are skipped with a count in the completion notification
- Remote must be in English input mode (Chinese IME will intercept key codes)
- Not code-signed — re-authorize Accessibility after each rebuild

## Build Requirements

- Swift 5.9+ toolchain (Xcode 15+ or standalone)
- No Xcode project needed — pure Swift Package Manager

## License

MIT
