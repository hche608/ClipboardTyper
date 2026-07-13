# PasteSimulator v2 — ClipboardTyper

## 用途

解决远程 RDP 连接禁用剪贴板粘贴的问题，通过 System Events `key code` 模拟真实键盘输入，绕过限制。

## 架构

```
ClipboardTyper.app (常驻后台菜单栏应用)
  → Carbon RegisterEventHotKey 注册全局快捷键
  → 触发后在主线程读取剪贴板（NSPasteboard 线程安全）
  → 分发到后台线程执行输入
  → NSAppleScript 调用 System Events key code 批量注入按键
  → System Events 通过 IOHIDSystem 层发送（与物理键盘同层级）
```

完全自包含，不依赖 Automator、Shortcuts、系统服务或任何第三方工具。

## 核心输入机制

```applescript
-- 连续大写批量发送（只按一次 Shift）
tell application "System Events" to key code {11, 14, 5, 34, 45} using {shift down}

-- 连续小写批量发送
tell application "System Events" to key code {4, 14, 37, 37, 31}

-- 特殊字符
tell application "System Events" to key code 27          -- 减号 -
tell application "System Events" to key code 33 using {shift down}  -- 左花括号 {
```

通过 `NSAppleScript` 内存调用，无需 fork 进程。

## 文件位置

| 组件 | 路径 |
|------|------|
| 应用（打包产物） | `./dist/ClipboardTyper.app` |
| 安装位置 | `/Applications/ClipboardTyper.app` |
| 源码目录 | `./Sources/` |
| 构建脚本 | `./build.sh` |
| 包定义 | `./Package.swift` |
| Info.plist | `./Info.plist` |
| 应用图标源 | `./AppIcon.png` (1254×1254) |
| 应用图标 | `./AppIcon.icns` |
| 配置文件 | `~/.config/ClipboardTyper/config.json` |

## 源码结构

```
Sources/
├── main.swift                  # 入口，设置 activationPolicy(.accessory)
├── AppDelegate.swift           # 应用生命周期、菜单栏、热键注册、权限检查
├── Config.swift                # AppConfig / HotKeyConfig / HotKeyDisplayable 协议、持久化
├── KeyMapping.swift            # keyCode ↔ 字符映射 (US QWERTY)、UCKeyTranslate
├── TypingEngine.swift          # 核心输入逻辑：批量 System Events key code 发送（含重入锁）
├── ManagedWindow.swift         # 窗口基类：NSWindowDelegate 生命周期管理
├── MemoryMonitor.swift         # 内存监控工具（mach_task_basic_info，RunLoop.main .common 模式）
├── Notification.swift          # NotificationManager 单例（UNUserNotificationCenter）
├── Logging.swift               # OSLog Logger 实例（app/typing/hotkey 三个 category）
├── SpeedSettingsWindow.swift   # 速度参数设置窗口
├── DebugWindow.swift           # 事件监听调试窗口（置顶 + NSTextStorage 高效追加 + 内存监控）
├── HotKeyRecorderWindow.swift  # 快捷键录制窗口
└── L10n.swift                  # 多语言文本（中文/英文，启动时缓存语言选择）
```

## 功能特性

- ⌨️ 全局快捷键触发（默认 ⌃⌥V，可自定义）
- 🎯 快捷键录制器（按键监听方式，非 checkbox）
- 🌐 多语言（中文/英文，跟随系统）
- 🔔 原生系统通知（UNUserNotificationCenter，显示 app 图标）
- 🚀 开机自启（LaunchAgent）
- 🔒 启动时检查辅助功能权限（自定义圆角图标弹窗）
- 🐛 Debug Events 窗口（置顶、一键复制 log、实时内存监控）
- 📋 菜单栏 SF Symbol 图标（`keyboard`，自动适配亮/暗模式）
- 🎨 自定义应用图标（1254×1254 PNG → icns 全尺寸）
- 📊 结构化日志（OSLog，可在 Console.app 按 subsystem/category 过滤）
- 🔐 线程安全（TypingEngine 重入锁防止并发触发竞争）

## 对比 v1

| | v1 AppleScript | v2 Swift + System Events key code |
|---|---|---|
| 速度 | ~200 字符/秒 (逐字符) | ~500+ 字符/秒 (批量) |
| 字符支持 | `keystroke` 依赖字符映射，`{}[]` 易错 | `key code` 精确控制物理按键，全字符 |
| 远程桌面兼容 | ✅ | ✅ (同 IOHIDSystem 层级) |
| Shift 处理 | `keystroke` 自动处理 | 批量 `using {shift down}`，不触发 Sticky Keys |
| 触发方式 | Automator + 系统快捷键 | 自注册全局热键 |
| 依赖 | Automator/Shortcuts | System Events (macOS 内置) |
| 快捷键配置 | 需去系统设置手动绑 | app 内录制修改 |
| 日志 | 无 | OSLog 结构化日志 |
| 线程安全 | N/A（单线程脚本） | NSLock 重入锁 + 主线程读剪贴板 |

## 编译与部署

```bash
cd ~/ClipboardTyper
./build.sh            # 编译并打包到 ./dist/ClipboardTyper.app
./build.sh --install  # 同上 + 部署到 /Applications 并重启
```

### App Bundle 结构

```
dist/ClipboardTyper.app/
└── Contents/
    ├── Info.plist          (CFBundleIdentifier, CFBundleIconFile, LSUIElement: true)
    ├── PkgInfo             (APPL???? 标记)
    ├── MacOS/
    │   └── ClipboardTyper  (arm64 Mach-O binary)
    └── Resources/
        ├── AppIcon.icns    (应用图标，含 16~1024px 全尺寸)
        └── AppIcon.png     (通知图标 fallback)
```

## 配置文件格式 (~/.config/ClipboardTyper/config.json)

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

### 速度参数说明

| 参数 | 默认值 | UI 范围 | 说明 |
|------|--------|---------|------|
| `interKeyDelay` | 5000 μs (5ms) | 1-50 ms | 每批按键之间的延迟 |
| `interChunkDelay` | 10000 μs (10ms) | 1-100 ms | 每 chunkSize 字符后额外停顿 |
| `chunkSize` | 100 | 10-500 | 多少字符触发额外停顿 |
| `batchSize` | 10 | 1-50 | 每次 AppleScript 调用最多发送几个同类字符 |

速度设置窗口提供：
- **Slider 滑块** — 拖动实时显示当前值（ms 单位）
- **预设方案** — ⚡快速 / ⚖️平衡 / 🛡安全 一键设置
- **预估速度** — 底部实时显示 "≈ XXX 字符/秒"

如果远程端丢字或乱序，使用「安全」预设或手动增大 `interKeyDelay`、减小 `batchSize`。

## 权限要求

1. **辅助功能**：系统设置 → 隐私与安全 → 辅助功能 → 添加 ClipboardTyper.app
2. **通知**：首次触发时系统自动弹出授权请求，允许即可

注意：每次替换未签名的二进制文件后，需要在辅助功能中重新删除并添加 app。

## 菜单栏选项

- ClipboardTyper v2 — 版本信息
- 快捷键: ⌃⌥v — 当前绑定
- Memory: XX.X MB — 实时内存占用（菜单打开时 2s 刷新，.common 模式保证菜单追踪时更新）
- 修改快捷键... — 打开录制窗口
- 速度设置... — Slider + 预设方案 + 预估速度
- 开机自启 — 切换 LaunchAgent
- 调试事件 — 打开事件监听窗口（置顶 + 内存 + 状态指示 + 日志裁剪）
- 退出 (Q) — 退出应用

## 快捷键录制流程

1. 点击「修改快捷键...」打开录制窗口
2. 窗口显示「等待输入...」
3. 按下修饰键 → 实时显示 `⌃⌥...`（继续监听）
4. 按下实际按键 → 锁定显示 `⌃⌥v`（停止监听）
5. 确认 → 保存并生效 / 清除重录 → 回到步骤 2

## 使用流程

1. 复制要输入的内容到剪贴板
2. 切换到目标窗口（本地或远程桌面），将光标放到目标输入位置
3. 按快捷键 `⌃⌥V` 触发
4. ClipboardTyper 开始批量发送键盘事件

## 开机自启

通过 LaunchAgent 实现：

```
~/Library/LaunchAgents/com.hche608.ClipboardTyper.plist
```

菜单栏点击「开机自启」切换。

## 技术细节

- 全局快捷键：Carbon `RegisterEventHotKey` API（handler 只安装一次）
- 键盘模拟：`NSAppleScript` → System Events `key code` (IOHIDSystem 层注入)
- 批量优化：连续同 Shift 状态字符合并为一条 `key code {list}` 命令，最多 batchSize 个一批
- keyCode 映射：US QWERTY 布局文件级常量 `keyCodeMap`（避免每次调用重建字典）
- keyCode 转显示字符：`UCKeyTranslate` (Carbon API)
- 快捷键录制：`NSEvent.addLocalMonitorForEvents` + `addGlobalMonitorForEvents`
- 通知：`UNUserNotificationCenter`（启动时一次性请求权限，自动显示 app 图标）
- 状态栏图标：SF Symbol `keyboard`（template image，适配亮/暗模式）
- 权限弹窗：`NSAlert` + 手动圆角裁剪 AppIcon (24pt radius)
- 窗口管理：`ManagedWindow` 基类 + `NSWindowDelegate.windowWillClose` + 异步释放
- 内存监控：`MemoryMonitor` 类（`mach_task_basic_info`，Timer on RunLoop.main .common 模式）
- 配置持久化：JSON 编码到 `~/.config/ClipboardTyper/config.json`，保存失败写入 OSLog
- 配置共享：`HotKeyDisplayable` 协议消除 displayString 重复逻辑
- 无窗口应用：`LSUIElement: true` + `setActivationPolicy(.accessory)`
- 日志系统：OSLog `Logger`（subsystem: com.hche608.ClipboardTyper，category: app/typing/hotkey）
- 线程安全：TypingEngine 使用 NSLock 防止重入；剪贴板在主线程读取后传递到后台
- Debug 窗口日志：NSTextStorage.append O(1) 追加 + 行计数器批量裁剪（避免 O(n²)）

## 为什么选择 System Events key code

远程桌面客户端（RDP）通过以下链路接收键盘输入：

```
IOHIDSystem (内核) → WindowServer → RDP 客户端 → 远程 Windows
```

- **System Events `key code`** 注入到 IOHIDSystem 层，RDP 客户端无法区分它和真实键盘，完整转发 Shift 状态
- **CGEvent.post()** 注入到 WindowServer 层，RDP 客户端可以识别它是合成事件，忽略 Shift 修饰键

### 调用 System Events 的方案对比

| | NSAppleScript (当前) | ScriptingBridge | NSAppleEventDescriptor |
|---|---|---|---|
| 实现难度 | ✅ 简单 | ⚠️ 中等 | ❌ 复杂 |
| 内存安全 | ⚠️ 每次创建/销毁 script 对象 | ✅ 固定对象 | ✅ 最精简 |
| 速度 | ~5ms | ~2ms | ~1ms |
| `key code {list} using {shift down}` 支持 | ✅ 原生 | ❌ 需要手动构建 | ⚠️ 需要手动构建 |
| 维护性 | ✅ 代码简洁 | ⚠️ 样板代码多 | ❌ 很底层 |

选择 NSAppleScript 的理由：`key code {list} using {shift down}` 这种批量+修饰键语法只有 AppleScript 原生支持，其他方案都需要手动构建 Apple Event descriptor，投入产出比不高。通过 `autoreleasepool` 和 `removeAll(keepingCapacity: true)` 缓解内存问题。

## 已知限制

- 未代码签名：更新二进制后需重新授权辅助功能
- 字符映射基于 US QWERTY 布局：非 ASCII 字符（中文、emoji）无法发送，完成通知中报告跳过数量
- 速度受 NSAppleScript 调用开销限制（比纯 CGEvent 慢，但比 v1 逐字符快）

## ⚠️ 潜在限制与风险评估

### 1. 远程端 IME（输入法）状态冲突

方案本质是模拟物理按键（Scancodes）。如果远程 Windows 当前处于中文输入法状态，发送的 key code 会被输入法拦截并转化为拼音，导致上屏错误。

**前提条件**：触发前必须确保远程端处于纯英文输入状态（如 US 键盘布局）。

### 2. 非 ASCII 字符处理

如果剪贴板内容包含无法映射的字符（中文注释、emoji 等），当前行为是静默跳过并在完成通知中报告跳过数量。

### 3. NSAppleScript 内存风险

`NSAppleScript` 在长时间运行和频繁实例化的应用中，历史上存在 Apple 底层的内存泄漏问题。

**当前缓解措施**：
- `autoreleasepool` 包裹每次调用
- `removeAll(keepingCapacity: true)` 复用数组内存
- 窗口关闭时 `contentView = nil` 释放子视图

**验证结果**：多次触发后内存稳定在 ~90MB（macOS 惰性回收），`purge` 后回落到 ~25MB，无真正泄漏。

### 4. 高延迟 RDP 网络环境

System Events `key code {list}` 在本地是同步执行的（等 IOHIDSystem 处理完才返回），本地不会乱序。但 RDP 协议传输端在网络拥塞时可能出现吞字或按键顺序错乱。

**应对策略**：
- 增大 `interKeyDelay`（如从 5ms 增到 20-50ms）
- 减小批次大小（如从 10 个字符一批减到 3-5 个）
- 使用 Speed Settings 窗口的「安全」预设

## 🚀 后续迭代计划

| 优先级 | 改进项 | 状态 |
|--------|--------|------|
| P0 | 非 ASCII 字符跳过通知 | ✅ 已实现 |
| P1 | interKeyDelay / 批次大小可配置 | ✅ 已实现（UI + config.json） |
| P1 | 自定义应用图标 | ✅ 已实现（PNG → icns，圆角弹窗） |
| P1 | 原生通知（显示 app 图标） | ✅ 已实现（UNUserNotificationCenter） |
| P1 | 状态栏 SF Symbol 图标 | ✅ 已实现（keyboard，适配暗/亮模式） |
| P1 | 窗口内存管理 | ✅ 已实现（ManagedWindow + windowWillClose + 异步释放） |
| P1 | 代码重构（SOLID） | ✅ 已实现（TypingEngine、NotificationManager、HotKeyDisplayable、MemoryMonitor） |
| P1 | Speed Settings UI 优化 | ✅ 已实现（Slider + 预设 + 预估速度） |
| P1 | Debug Window UI 优化 | ✅ 已实现（Toggle + 状态标题 + NSTextStorage 高效追加 + 行计数裁剪） |
| P1 | 全量多语言 | ✅ 已实现（所有 UI 文字统一由 L10n.swift 管理） |
| P1 | 结构化日志 | ✅ 已实现（OSLog Logger，三个 category） |
| P1 | 线程安全 | ✅ 已实现（NSLock 重入锁 + 主线程读剪贴板） |
| P1 | 正式 .app 打包 | ✅ 已实现（dist/ 目录，含 PkgInfo） |
| P2 | 代码签名 | 待实现 |

## 已验证不可行的方案

### CGEvent + Shift flagsChanged + keyCode

```swift
CGEvent(virtualKey: 56, keyDown: true).flags = .maskShift → post(.cghidEventTap)
CGEvent(virtualKey: keyCode, keyDown: true).flags = .maskShift → post(.cghidEventTap)
CGEvent(virtualKey: keyCode, keyDown: false) → post(.cghidEventTap)
CGEvent(virtualKey: 56, keyDown: false).flags = [] → post(.cghidEventTap)
```

**现象**：本地正确，远程 RDP 全是小写。
**原因**：Microsoft Remote Desktop for Mac 不转发 CGEvent 合成的 Shift flagsChanged 事件。RDP 客户端通过硬件状态查询修饰键，而非信任 CGEvent 的 flags。
**结论**：CGEvent 层级的注入无法让 RDP 正确识别 Shift 状态。

### CGEvent + keyboardSetUnicodeString

```swift
CGEvent(virtualKey: 0, keyDown: true)
event.keyboardSetUnicodeString(...)  // 设置 unicode 字符
event.post(.cghidEventTap)
```

**现象**：远程端所有字符都变成 "a"。
**原因**：RDP 客户端只看 keyCode（物理扫描码），不看 unicode string。keyCode=0 对应 A 键。
**结论**：不能依赖 keyboardSetUnicodeString 传递字符信息。
