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
            trace("on: permission")
            // A look that never answers (the iOS 27.2 simulator, 1.7) counts as never
            // asked: the request then answers with the current choice at once if one was
            // made, or shows the system's alert.
            let current = await Self.withTimeout(5, "on: permission", default: ReminderPermission.undetermined) { [scheduler] in
                await scheduler.permission()
            }
            trace("on: \(current)")
            let allowed = switch current {
            case .allowed: true
            case .undetermined: await scheduler.requestPermission()
            case .refused: false
            }
            trace("on: allowed=\(allowed)")
            refused = !allowed
            if allowed {
                // The answer just given, not a fresh look.
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
        refused = await Self.withTimeout(5, "refresh: permission", default: ReminderPermission.undetermined) { [scheduler] in
            await scheduler.permission()
        } == .refused
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
            trace("sync: permission")
            let allowed: Bool
            if let known {
                allowed = known
            } else {
                // A look that never answers is taken as allowed: a request added without
                // permission is simply never shown.
                allowed = await Self.withTimeout(5, "sync: permission", default: ReminderPermission.allowed) {
                    await scheduler.permission()
                } != .refused
            }
            trace("sync: replace allowed=\(allowed) wanted=\(wanted.count)")
            await scheduler.replace(Reminders.allIdentifiers, with: allowed ? wanted : [])
            #if DEBUG
            trace("sync: pending")
            pendingSummary = await Self.withTimeout(5, "sync: pending", default: [String]()) {
                await scheduler.pending()
            }.joined(separator: ", ")
            trace("sync: done " + (await Self.withTimeout(5, "sync: settings", default: "") {
                await scheduler.diagnostics()
            }))
            #endif
        }
    }

    /// The result of `operation`, or `value` if it hasn't answered within `seconds`. The
    /// notification centre's calls are awaited this way since one never answered on the
    /// iOS 27.2 simulator (1.7), and every later re-sync waited behind it.
    /// A call that times out is noted in the debug trace as `<label> timed out`, which
    /// the UI tests read.
    nonisolated static func withTimeout<T: Sendable>(
        _ seconds: Double, _ label: String, default value: T, _ operation: @escaping @Sendable () async -> T
    ) async -> T {
        let once = ResumeOnce<T>()
        return await withCheckedContinuation { continuation in
            once.set(continuation)
            Task { once.resume(await operation()) }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                if once.resume(value) {
                    #if DEBUG
                    await MainActor.run { ReminderCenter.shared.trace("\(label) timed out") }
                    #endif
                }
            }
        }
    }

    /// What the reminders are doing, step by step, for the UI tests (`remindersDiagnostics`).
    func trace(_ step: String) {
        #if DEBUG
        diagnostics = String((diagnostics.isEmpty ? step : diagnostics + " > " + step).suffix(600))
        #endif
    }

    private func turnAllOff(in settings: SettingsStore) {
        for (key, reminder) in settings.reminders where reminder.isOn {
            settings.reminders[key]?.isOn = false
        }
    }
}

/// Resumes a continuation once, whichever of two tasks answers first (`withTimeout`).
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?
    private var pending: T?
    private var done = false

    func set(_ continuation: CheckedContinuation<T, Never>) {
        lock.withLock {
            if let pending, !done {
                done = true
                continuation.resume(returning: pending)
            } else if !done {
                self.continuation = continuation
            }
        }
    }

    /// Whether this value is the one the continuation gets.
    @discardableResult
    func resume(_ value: T) -> Bool {
        lock.withLock {
            guard !done, pending == nil else { return false }
            if let continuation {
                done = true
                continuation.resume(returning: value)
                self.continuation = nil
            } else {
                pending = value
            }
            return true
        }
    }
}
