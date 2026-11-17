import Foundation
import UserNotifications

/// One repeating reminder, as the system is asked to schedule it.
struct ScheduledReminder: Equatable, Sendable {
    var identifier: String
    var title: String
    var hour: Int
    var minute: Int
}

/// Whether the app may show notifications.
enum ReminderPermission: Sendable {
    /// Never asked: nothing asks until the first hour is turned on (decided 2026-11-14).
    case undetermined
    case allowed
    /// Refused when asked, or turned off later in iOS Settings.
    case refused
}

/// The system's notification centre, behind a small interface so the UI tests can use
/// a stand-in (`BREVIARIUM_NOTIFICATIONS`, debug builds only).
protocol ReminderScheduling: Sendable {
    func permission() async -> ReminderPermission
    /// Asks for permission (the system's alert, the first time only).
    func requestPermission() async -> Bool
    /// Removes every request in `identifiers`, then adds `reminders`.
    func replace(_ identifiers: [String], with reminders: [ScheduledReminder]) async
    /// What is scheduled, `hour.Vespera 18:00`, for the UI tests.
    func pending() async -> [String]
    #if DEBUG
    /// The system's notification settings and the last error, for the UI tests.
    func diagnostics() async -> String
    #endif
}

/// The real one: local notifications only (1.6, `docs/1.6_plan.md`). No push, no
/// entitlement, no background mode, nothing that a free Apple ID can't sign.
struct SystemReminderScheduler: ReminderScheduling {
    func permission() async -> ReminderPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .undetermined
        case .denied: .refused
        case .authorized, .provisional, .ephemeral: .allowed
        @unknown default: .refused
        }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replace(_ identifiers: [String], with reminders: [ScheduledReminder]) async {
        let center = UNUserNotificationCenter.current()
        // Only the ones no longer wanted: a request added under an identifier already
        // pending replaces it. Removing them all first raced the adds on iOS 27 (1.7, App
        // CI on the iOS 27.2 simulator): the removal, which isn't awaited, could land
        // after the new request and take it away.
        let kept = Set(reminders.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: identifiers.filter { !kept.contains($0) })
        for reminder in reminders {
            // The hour's Latin title alone (decided 2026-11-14): no body, no subtitle, no
            // badge; iOS shows the app's name above it. Never `.timeSensitive`, which
            // needs an entitlement.
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.sound = .default
            content.interruptionLevel = .active
            // Every day at this time in the phone's local time, so it follows a change
            // of time zone or summer time.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute), repeats: true
            )
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
            } catch {
                #if DEBUG
                lastError.set("\(error)")
                #endif
            }
        }
    }

    #if DEBUG
    /// The last error from `add`, for the UI tests' status line.
    let lastError = LastError()

    func diagnostics() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return "auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) error=\(lastError.get() ?? "none")"
    }
    #endif

    func pending() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let hour = trigger.dateComponents.hour, let minute = trigger.dateComponents.minute
            else { return nil }
            return "\(request.identifier) \(String(format: "%02d:%02d", hour, minute))"
        }
        .sorted()
    }
}

#if DEBUG
/// The UI tests' stand-in (`BREVIARIUM_NOTIFICATIONS`): `granted` asks and is allowed,
/// `allowed` is allowed already, `denied` asks and is refused. It shows no alert and
/// schedules nothing on the simulator.
actor StandInReminderScheduler: ReminderScheduling {
    private var status: ReminderPermission
    private let grants: Bool
    private var scheduled: [ScheduledReminder] = []

    init(mode: String) {
        status = mode == "allowed" ? .allowed : .undetermined
        grants = mode != "denied"
    }

    func permission() -> ReminderPermission { status }

    func requestPermission() -> Bool {
        if status == .undetermined { status = grants ? .allowed : .refused }
        return status == .allowed
    }

    func replace(_ identifiers: [String], with reminders: [ScheduledReminder]) {
        scheduled.removeAll { identifiers.contains($0.identifier) }
        scheduled += reminders
    }

    func diagnostics() -> String { "stand-in" }

    func pending() -> [String] {
        scheduled.map { "\($0.identifier) \(String(format: "%02d:%02d", $0.hour, $0.minute))" }.sorted()
    }
}
#endif

#if DEBUG
/// The last scheduling error, kept for the UI tests' status line (`diagnostics()`).
final class LastError: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    func set(_ text: String) { lock.withLock { value = text } }
    func get() -> String? { lock.withLock { value } }
}
#endif
