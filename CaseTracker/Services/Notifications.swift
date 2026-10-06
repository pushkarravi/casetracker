import Foundation
import UserNotifications

enum NotificationManager {
    static let enabledKey = "notifyOnStatusChange"

    static var isEnabledByUser: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func notify(_ changes: [CaseRefresher.Change]) async {
        guard isEnabledByUser, !changes.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        for change in changes {
            let content = UNMutableNotificationContent()
            content.title = change.caseName
            content.subtitle = change.caseName == change.receiptNumber ? "" : change.receiptNumber
            content.body = change.newStatus
            content.sound = .default
            content.threadIdentifier = change.receiptNumber
            let request = UNNotificationRequest(
                identifier: "\(change.receiptNumber)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}

/// Shows status-change banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
