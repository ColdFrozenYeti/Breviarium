import Foundation

/// Keeps the system's scheduled reminders the same as the saved ones (1.6,
/// `docs/1.6_plan.md`), and asks for permission when the first hour is turned on, never
/// earlier.
@MainActor
final class ReminderCenter: ObservableObject {
    static let shared = ReminderCenter()

    /// Permission was refused, or later turned off in iOS Settings: the page says how
    /// to allow it.
    @Published private(set) var refused = false

    /// What is scheduled (`hour.Vespera 18:00`, …), for the UI tests.
    @Published private(set) var pendingSummary = ""
    /// The system's notification settings and the last error, for the UI tests.
    @Published private(set) var diagnostics = ""

    private let scheduler: any ReminderScheduling
    /// The last re-sync: each waits for the one before, so they never interleave.
    private var lastSync: Task<Void, Never>?

    private init() {
        #if DEBUG
        if let mode = ProcessInfo.processInfo.environment["BREVIARIUM_NOTIFICATIONS"] {
            scheduler = StandInReminderScheduler(mode: mode)
            return
        }
        #endif
        scheduler = SystemReminderScheduler()
    }

    /// Turns an hour on, at its last time or else its suggested one, asking for
    /// permission if it was never asked. Refused, every switch goes back off; the times
    /// are kept.
    func turnOn(_ hour: OfficeHour, in settings: SettingsStore) {
        var reminder = settings.reminders[hour.key] ?? Reminders.suggested(hour)
        reminder.isOn = true
        settings.reminders[hour.key] = reminder
        Task {
            let allowed = switch await scheduler.permission() {
            case .allowed: true
            case .undetermined: await scheduler.requestPermission()
            case .refused: false
            }
            refused = !allowed
            if allowed {
                // The answer just given, not a fresh look: on iOS 27 the notification
                // settings can still read "not determined" for a moment after *Allow*
                // (App CI on the iOS 27.2 simulator, 1.7), and the re-sync scheduled
                // nothing.
                sync(settings.reminders, allowed: true)
            } else {
                turnAllOff(in: settings)
            }
        }
    }

    func turnOff(_ hour: OfficeHour, in settings: SettingsStore) {
        settings.reminders[hour.key]?.isOn = false
    }

    /// At launch, on coming to the foreground and when the page appears: notices a
    /// permission turned off in iOS Settings, and re-syncs.
    func refresh(_ settings: SettingsStore) async {
        refused = await scheduler.permission() == .refused
        if refused { turnAllOff(in: settings) }
        sync(settings.reminders)
    }

    /// Removes every reminder request, then adds the ones that are on (none without
    /// permission). Called whenever the saved reminders change (`SettingsStore`);
    /// `allowed` is passed when permission was just granted.
    func sync(_ reminders: [String: HourReminder], allowed known: Bool? = nil) {
        let wanted = Reminders.scheduled(from: reminders)
        let previous = lastSync
        lastSync = Task { [scheduler] in
            await previous?.value
            let allowed: Bool
            if let known {
                allowed = known
            } else {
                allowed = await scheduler.permission() == .allowed
            }
            await scheduler.replace(Reminders.allIdentifiers, with: allowed ? wanted : [])
            #if DEBUG
            pendingSummary = await scheduler.pending().joined(separator: ", ")
            diagnostics = "allowed=\(allowed) wanted=\(wanted.count) " + (await scheduler.diagnostics())
            #endif
        }
    }

    private func turnAllOff(in settings: SettingsStore) {
        for (key, reminder) in settings.reminders where reminder.isOn {
            settings.reminders[key]?.isOn = false
        }
    }
}
