import Carbon
import Cocoa

// MARK: - Key Code Display

// Converts a keyCode to a human-readable character for display in UI.
// Uses UCKeyTranslate which respects the current keyboard layout.
func keyCodeToDisplay(_ keyCode: UInt32, shift: Bool) -> String {
    let base = keyCodeToString(keyCode)
    if base.count == 1 && base.first?.isLetter == true {
        return shift ? base.uppercased() : base.lowercased()
    }
    return base
}

// UCKeyTranslate is the only reliable way to map keyCode → display character
// across different keyboard layouts. Falls back to a hardcoded special keys table.
func keyCodeToString(_ keyCode: UInt32) -> String {
    if let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
       let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) {
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        
        layoutData.withUnsafeBytes { rawBuffer in
            let layoutPtr = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        
        if length > 0 {
            let result = String(utf16CodeUnits: chars, count: length)
            if !result.isEmpty && result.unicodeScalars.first?.value ?? 0 >= 32 {
                return result
            }
        }
    }
    
    // Fallback for keys that UCKeyTranslate returns control characters for
    let specialKeys: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 118: "F4", 120: "F2",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    return specialKeys[keyCode] ?? "Key\(keyCode)"
}

// MARK: - Character to Key Code (US QWERTY)

// Static mapping table for ASCII characters to macOS virtual key codes.
// Why static table instead of reverse-UCKeyTranslate:
// - We only support US QWERTY for RDP input (remote must be in English mode anyway)
// - Reverse lookup is expensive and unreliable across layouts
// - Bool indicates whether Shift is needed for this character
//
// Returns nil for non-ASCII characters (Chinese, emoji) — caller skips them.
//
// File-level constant: avoids rebuilding the dictionary on every call.
private let keyCodeMap: [Character: (CGKeyCode, Bool)] = [
    "a": (0, false), "A": (0, true),
    "s": (1, false), "S": (1, true),
    "d": (2, false), "D": (2, true),
    "f": (3, false), "F": (3, true),
    "h": (4, false), "H": (4, true),
    "g": (5, false), "G": (5, true),
    "z": (6, false), "Z": (6, true),
    "x": (7, false), "X": (7, true),
    "c": (8, false), "C": (8, true),
    "v": (9, false), "V": (9, true),
    "b": (11, false), "B": (11, true),
    "q": (12, false), "Q": (12, true),
    "w": (13, false), "W": (13, true),
    "e": (14, false), "E": (14, true),
    "r": (15, false), "R": (15, true),
    "y": (16, false), "Y": (16, true),
    "t": (17, false), "T": (17, true),
    "1": (18, false), "!": (18, true),
    "2": (19, false), "@": (19, true),
    "3": (20, false), "#": (20, true),
    "4": (21, false), "$": (21, true),
    "6": (22, false), "^": (22, true),
    "5": (23, false), "%": (23, true),
    "=": (24, false), "+": (24, true),
    "9": (25, false), "(": (25, true),
    "7": (26, false), "&": (26, true),
    "-": (27, false), "_": (27, true),
    "8": (28, false), "*": (28, true),
    "0": (29, false), ")": (29, true),
    "]": (30, false), "}": (30, true),
    "o": (31, false), "O": (31, true),
    "u": (32, false), "U": (32, true),
    "[": (33, false), "{": (33, true),
    "i": (34, false), "I": (34, true),
    "p": (35, false), "P": (35, true),
    "l": (37, false), "L": (37, true),
    "j": (38, false), "J": (38, true),
    "'": (39, false), "\"": (39, true),
    "k": (40, false), "K": (40, true),
    ";": (41, false), ":": (41, true),
    "\\": (42, false), "|": (42, true),
    ",": (43, false), "<": (43, true),
    "/": (44, false), "?": (44, true),
    "n": (45, false), "N": (45, true),
    "m": (46, false), "M": (46, true),
    ".": (47, false), ">": (47, true),
    " ": (49, false),
    "`": (50, false), "~": (50, true),
]

func charToKeyCode(_ char: Character) -> (CGKeyCode, Bool)? {
    keyCodeMap[char]
}
