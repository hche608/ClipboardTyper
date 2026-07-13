# PasteSimulator v1 — 第一代方案记录

## 用途

解决远程 RDP 连接禁用剪贴板粘贴的问题，通过模拟键盘逐字符输入来绕过限制。

## 架构

```
⌃⇧V (快捷键)
  → 系统设置 → 键盘 → 快捷键 → 服务 → General → 模拟粘貼
    → ~/Library/Services/模拟粘贴.workflow (Automator 快速操作)
      → AppleScript: tell app "PasteSimulator" → activate → run
        → /Applications/PasteSimulator.app (AppleScript 应用)
```

## 文件位置

| 组件 | 路径 |
|------|------|
| 应用 | `/Applications/PasteSimulator.app` |
| 核心脚本 | `/Applications/PasteSimulator.app/Contents/Resources/Scripts/main.scpt` |
| Automator 工作流 | `~/Library/Services/模拟粘贴.workflow` |
| 备份 | `~/iCloud Drive (Archive)/PasteSimulator.app` |
| 原始 scpt 文件 | `~/iCloud Drive (Archive)/Script Editor/PasteSimulator.scpt` |

## 核心脚本（main.scpt）

```applescript
tell application "System Events"
    set theText to (the clipboard as text)
    repeat with eachChar in characters of theText
        if eachChar is linefeed then
            key code 36 -- 换行符替换为回车键
        else
            keystroke eachChar
        end if
        delay 0.005 -- 控制输入速度（单位：秒）
    end repeat
end tell
```

## Automator 工作流内容

类型：快速操作（Services Menu）  
输入：无  
应用范围：任何应用程序

AppleScript 动作：
```applescript
on run {input, parameters}
    tell application "PasteSimulator"
        activate
        run
    end tell
    return input
end run
```

## 快捷键配置

- 位置：系统设置 → 键盘 → 快捷键 → 服务 → General
- 服务名：模拟粘貼
- 快捷键：⌃⇧V (Control + Shift + V)

## 配置步骤（从零复现）

1. 打开 Script Editor，写入核心脚本
2. 文件 → 导出 → 文件格式选「应用程序」，保存为 `PasteSimulator.app`
3. 将 app 移动到 `/Applications/`
4. 打开 Automator → 新建 → 快速操作
5. 设置「工作流程接收」为「没有输入」，位于「任何应用程序」
6. 添加「运行 AppleScript」动作，写入调用 PasteSimulator 的代码
7. 保存为「模拟粘贴」
8. 系统设置 → 键盘 → 快捷键 → 服务 → General → 找到「模拟粘貼」→ 绑定 ⌃⇧V
9. 系统设置 → 隐私与安全 → 辅助功能 → 授权 PasteSimulator.app

## 已知问题

- **大文本极慢**：逐字符输入，每字符 5ms，1000 字符需要 5 秒，大 JSON 需要几分钟
- **特殊字符不稳定**：`keystroke` 对 `{}[]"\` 等需要修饰键的字符在某些键盘布局下会出错
- **无进度反馈**：运行时无法知道进度，也无法中途取消
- **Tab 字符未处理**：只处理了换行，Tab 会被当普通字符尝试输入
