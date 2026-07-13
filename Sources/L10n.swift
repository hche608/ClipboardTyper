import Foundation

// MARK: - Localization
enum L10n {
    enum Lang {
        case zh, en
    }
    
    /// Cached at launch — language doesn't change without app restart.
    static let current: Lang = {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh") ? .zh : .en
    }()
    
    static var appName: String { "ClipboardTyper" }
    
    static var launched: String {
        switch current {
        case .zh: return "✅ 已启动，快捷键: "
        case .en: return "✅ Launched, hotkey: "
        }
    }
    
    static var hotkey: String {
        switch current {
        case .zh: return "快捷键: "
        case .en: return "Hotkey: "
        }
    }
    
    static var changeHotKey: String {
        switch current {
        case .zh: return "修改快捷键..."
        case .en: return "Change Hotkey..."
        }
    }
    
    static var launchAtLogin: String {
        switch current {
        case .zh: return "开机自启"
        case .en: return "Launch at Login"
        }
    }
    
    static var quit: String {
        switch current {
        case .zh: return "退出"
        case .en: return "Quit"
        }
    }
    
    static var clipboardEmpty: String {
        switch current {
        case .zh: return "❌ 剪贴板为空"
        case .en: return "❌ Clipboard is empty"
        }
    }
    
    static func typingStarted(_ count: Int) -> String {
        switch current {
        case .zh: return "⌨️ 开始输入 \(count) 个字符..."
        case .en: return "⌨️ Typing \(count) characters..."
        }
    }
    
    static func typingDone(_ count: Int) -> String {
        switch current {
        case .zh: return "✅ 完成，共输入 \(count) 个字符"
        case .en: return "✅ Done, typed \(count) characters"
        }
    }
    
    static func hotkeyRegisterFailed(_ code: OSStatus) -> String {
        switch current {
        case .zh: return "❌ 快捷键注册失败 (code: \(code))"
        case .en: return "❌ Hotkey registration failed (code: \(code))"
        }
    }
    
    static func hotkeyUpdated(_ key: String) -> String {
        switch current {
        case .zh: return "✅ 快捷键已更新为: \(key)"
        case .en: return "✅ Hotkey updated to: \(key)"
        }
    }
    
    static var permissionTitle: String {
        switch current {
        case .zh: return "需要辅助功能权限"
        case .en: return "Accessibility Permission"
        }
    }
    
    static var permissionMessage: String {
        switch current {
        case .zh: return "ClipboardTyper 需要辅助功能权限来注册全局快捷键并模拟键盘输入。\n\n请在系统设置中授权，授权后自动生效。"
        case .en: return "ClipboardTyper needs Accessibility access to register global hotkeys and simulate keyboard input.\n\nGrant access in System Settings. It will take effect automatically."
        }
    }
    
    static var openSettings: String {
        switch current {
        case .zh: return "打开系统设置"
        case .en: return "Open Settings"
        }
    }
    
    static var quitButton: String {
        switch current {
        case .zh: return "退出"
        case .en: return "Quit"
        }
    }
    
    static var permissionTimeout: String {
        switch current {
        case .zh: return "⚠️ 等待授权超时，请手动重启应用"
        case .en: return "⚠️ Authorization timeout, please restart manually"
        }
    }
    
    static var changeHotKeyTitle: String {
        switch current {
        case .zh: return "设置新的快捷键"
        case .en: return "Set New Hotkey"
        }
    }
    
    static var confirm: String {
        switch current {
        case .zh: return "确认"
        case .en: return "OK"
        }
    }
    
    static var cancel: String {
        switch current {
        case .zh: return "取消"
        case .en: return "Cancel"
        }
    }
    
    static var pressHotKey: String {
        switch current {
        case .zh: return "请按下你想要的快捷键组合"
        case .en: return "Press your desired hotkey combination"
        }
    }
    
    static var waitingForInput: String {
        switch current {
        case .zh: return "等待输入..."
        case .en: return "Waiting..."
        }
    }
    
    static var currentHotKey: String {
        switch current {
        case .zh: return "当前: "
        case .en: return "Current: "
        }
    }
    
    static var hotkeyRecorded: String {
        switch current {
        case .zh: return "已录制，确认保存或清除重录"
        case .en: return "Recorded. Confirm to save or clear to re-record"
        }
    }
    
    static var reRecord: String {
        switch current {
        case .zh: return "清除重录"
        case .en: return "Clear"
        }
    }
    
    static var launchAtLoginEnabled: String {
        switch current {
        case .zh: return "已开启开机自启"
        case .en: return "Launch at Login enabled"
        }
    }
    
    static var launchAtLoginDisabled: String {
        switch current {
        case .zh: return "已关闭开机自启"
        case .en: return "Launch at Login disabled"
        }
    }
    
    static var speedSettings: String {
        switch current {
        case .zh: return "速度设置..."
        case .en: return "Speed Settings..."
        }
    }
    
    static var speedSettingsTitle: String {
        switch current {
        case .zh: return "速度参数设置"
        case .en: return "Speed Settings"
        }
    }
    
    static var interKeyDelayLabel: String {
        switch current {
        case .zh: return "批次间延迟"
        case .en: return "Inter-batch delay"
        }
    }
    
    static var interChunkDelayLabel: String {
        switch current {
        case .zh: return "分块额外延迟"
        case .en: return "Chunk extra delay"
        }
    }
    
    static var chunkSizeLabel: String {
        switch current {
        case .zh: return "分块大小（字符数）"
        case .en: return "Chunk size (chars)"
        }
    }
    
    static var batchSizeLabel: String {
        switch current {
        case .zh: return "每批字符数"
        case .en: return "Batch size (chars)"
        }
    }
    
    static var resetDefaults: String {
        switch current {
        case .zh: return "恢复默认"
        case .en: return "Reset"
        }
    }
    
    static var speedUpdated: String {
        switch current {
        case .zh: return "✅ 速度参数已更新"
        case .en: return "✅ Speed settings updated"
        }
    }
    
    static func typingDoneWithSkipped(_ typed: Int, _ skipped: Int) -> String {
        switch current {
        case .zh: return "✅ 完成 \(typed) 字符，⚠️ 跳过 \(skipped) 个不支持字符"
        case .en: return "✅ Done \(typed) chars, ⚠️ skipped \(skipped) unsupported"
        }
    }
    
    static var alreadyTyping: String {
        switch current {
        case .zh: return "⚠️ 正在输入中，忽略重复触发"
        case .en: return "⚠️ Already typing, ignoring trigger"
        }
    }
    
    // MARK: - Speed Settings Presets & Hints
    
    static var presetFast: String {
        switch current {
        case .zh: return "⚡ 快速"
        case .en: return "⚡ Fast"
        }
    }
    
    static var presetBalanced: String {
        switch current {
        case .zh: return "⚖️ 平衡"
        case .en: return "⚖️ Balanced"
        }
    }
    
    static var presetSafe: String {
        switch current {
        case .zh: return "🛡 安全"
        case .en: return "🛡 Safe"
        }
    }
    
    static var hintInterKeyDelay: String {
        switch current {
        case .zh: return "丢字时增大"
        case .en: return "Increase if chars drop"
        }
    }
    
    static var hintInterChunkDelay: String {
        switch current {
        case .zh: return "分块间额外停顿"
        case .en: return "Pause between chunks"
        }
    }
    
    static var hintChunkSize: String {
        switch current {
        case .zh: return "触发停顿的字符数"
        case .en: return "Chars before pause"
        }
    }
    
    static var hintBatchSize: String {
        switch current {
        case .zh: return "每次调用发送字符数"
        case .en: return "Chars per call"
        }
    }
    
    static func estimateSpeed(_ cps: Int) -> String {
        switch current {
        case .zh: return "≈ \(cps) 字符/秒"
        case .en: return "≈ \(cps) chars/sec"
        }
    }
    
    // MARK: - Debug Window
    
    static var debugMonitoring: String {
        switch current {
        case .zh: return "调试: 监听中 ●"
        case .en: return "Debug: Monitoring ●"
        }
    }
    
    static var debugStopped: String {
        switch current {
        case .zh: return "调试: 已停止 ○"
        case .en: return "Debug: Stopped ○"
        }
    }
    
    static var debugToggleStop: String {
        switch current {
        case .zh: return "⏸ 停止"
        case .en: return "⏸ Stop"
        }
    }
    
    static var debugToggleStart: String {
        switch current {
        case .zh: return "▶ 开始"
        case .en: return "▶ Start"
        }
    }
    
    static var debugClear: String {
        switch current {
        case .zh: return "清空"
        case .en: return "Clear"
        }
    }
    
    static var debugCopyLog: String {
        switch current {
        case .zh: return "复制日志"
        case .en: return "Copy Log"
        }
    }
    
    static var debugMenuTitle: String {
        switch current {
        case .zh: return "调试事件"
        case .en: return "Debug Events"
        }
    }
}
