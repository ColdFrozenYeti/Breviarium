import Foundation
import UserNotifications

/// A tap on a reminder (1.6): the notification centre's delegate, set when the app
/// starts (`BreviariumApp.init`) so a tap that launches the app is caught too. It turns
/// the tap into the widgets' link, which `ContentView` opens as it opens a widget's.
@MainActor
final class NotificationRouter: NSObject, ObservableObject {
    static let shared = NotificationRouter()

    /// The link to open; `ContentView` opens it and clears it.
    @Published var link: URL?

    private override init() {
        super.init()
        #if DEBUG
        // `BREVIARIUM_SNAPSHOT_REMINDER=Laudes@2026-12-25`: acts as a tap on that hour's
        // reminder delivered on that day, for the UI tests.
        if let tap = ProcessInfo.processInfo.environment["BREVIARIUM_SNAPSHOT_REMINDER"] {
            let parts = tap.split(separator: "@").map(String.init)
            let date = parts.count == 2 ? parts[1].split(separator: "-").compactMap { Int($0) } : []
            if date.count == 3 {
                link = WidgetData.link(hour: parts[0], day: date[2], month: date[1], year: date[0])
            }
        }
        #endif
    }
}

extension NotificationRouter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let url = Reminders.link(identifier: response.notification.request.identifier, delivered: response.notification.date)
        await MainActor.run { self.link = url }
    }

    /// With the app open, the reminder still shows as a banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
