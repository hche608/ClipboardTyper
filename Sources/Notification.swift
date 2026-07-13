import UserNotifications
import OSLog

// MARK: - Notification Manager

// Singleton to manage UNUserNotificationCenter.
// Why singleton: requestAuthorization() must only be called once at launch,
// and the notification center instance is shared anyway.
// Why UNUserNotificationCenter over osascript: notifications display the app's
// own icon (from CFBundleIconFile) instead of Script Editor's icon.
//
// Note: No UNUserNotificationCenterDelegate is set because this app uses
// notifications purely as status feedback — foreground banners are not needed,
// and users don't interact with them. If foreground display is ever needed,
// implement willPresent and return [.banner, .sound, .list].
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Call once at app launch. Subsequent sends work regardless of authorization
    /// state (they just silently fail if denied).
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error = error {
                Logger.app.error("Notification authorization error: \(error.localizedDescription)")
            } else {
                Logger.app.info("Notification authorization granted: \(granted)")
            }
        }
    }
    
    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // nil trigger = deliver immediately
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// Global convenience function so callers don't need to know about the singleton.
func sendNotification(title: String, body: String) {
    NotificationManager.shared.send(title: title, body: body)
}
