// swift-tools-version: 6.0

import PackageDescription

// ClipboardTyper is built as a SwiftPM executable (no .xcodeproj needed).
// Why SwiftPM over Xcode project:
// - Single `swift build` command, no IDE dependency
// - Clean git history (no pbxproj noise)
// - Easy CI integration
//
// Linked frameworks:
// - Carbon: RegisterEventHotKey API for global hotkey (no Swift-native alternative)
// - Cocoa: NSApplication, NSStatusBar, NSWindow, NSAppleScript for menu-bar app + key injection
// - UserNotifications: UNUserNotificationCenter for native notification banners
//
// Testing:
// - Tests use @testable import to access internal symbols without making them public.
// - Requires Xcode (full SDK) to run — Command Line Tools alone don't include XCTest.
let package = Package(
    name: "ClipboardTyper",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClipboardTyper",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Cocoa"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "ClipboardTyperTests",
            dependencies: ["ClipboardTyper"],
            path: "Tests"
        )
    ]
)
