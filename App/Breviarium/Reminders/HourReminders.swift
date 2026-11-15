import BreviariumKit
import Foundation

/// One hour's reminder (1.6, `docs/1.6_plan.md`): on or off, and its time of day. The
/// time is kept when the reminder is turned off, so turning it back on restores it.
struct HourReminder: Codable, Equatable, Sendable {
    var isOn: Bool
    var hour: Int
    var minute: Int
}

/// The reminders' fixed parts: the page's rows, the suggested times, the identifiers
/// and the link a tap opens. Nothing liturgical: a reminder names an hour, and the
/// office it opens is the app's own, under its own *Ritus* and *Officium*.
enum Reminders {
    /// The nine rows (decided 2026-11-14): the eight hours, with the Martyrology after
    /// Prime as in the hour picker, but the same whatever the *Ritus* or *Officium*.
    static let rows: [OfficeHour] = CanonicalHour.allCases.flatMap { hour -> [OfficeHour] in
        hour == .prima ? [.hour(hour), .martyrologium] : [.hour(hour)]
    }

    /// The time an hour takes when it is first turned on (the user's, 14 November 2026);
    /// any hour can then take any time.
    static func suggested(_ hour: OfficeHour) -> HourReminder {
        let (h, m): (Int, Int) = switch hour {
        case .hour(.matutinum): (5, 0)
        case .hour(.laudes): (7, 0)
        case .hour(.prima): (8, 0)
        case .martyrologium: (8, 15)
        case .hour(.tertia): (9, 0)
        case .hour(.sexta): (12, 0)
        case .hour(.nona): (15, 0)
        case .hour(.vesperae): (18, 0)
        case .hour(.completorium): (21, 0)
        }
        return HourReminder(isOn: false, hour: h, minute: m)
    }

    static let identifierPrefix = "hour."

    /// `hour.Vespera`, `hour.martyrologium`: one request per row, so adding one replaces
    /// the last.
    static func identifier(_ hour: OfficeHour) -> String { identifierPrefix + hour.key }

    static var allIdentifiers: [String] { rows.map(identifier) }

    /// The link a tap on a delivered reminder opens: its hour, on the day it was
    /// delivered in the phone's own calendar (decided 2026-11-14: nothing is shifted to
    /// the day before), through the widgets' link (`WidgetData.link`).
    static func link(identifier: String, delivered: Date, calendar: Calendar = .current) -> URL? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let key = String(identifier.dropFirst(identifierPrefix.count))
        let day = calendar.dateComponents([.year, .month, .day], from: delivered)
        guard let year = day.year, let month = day.month, let date = day.day else { return nil }
        return WidgetData.link(hour: key, day: date, month: month, year: year)
    }

    /// What the system is asked to schedule, from the saved reminders.
    static func scheduled(from reminders: [String: HourReminder]) -> [ScheduledReminder] {
        rows.compactMap { hour in
            guard let reminder = reminders[hour.key], reminder.isOn else { return nil }
            return ScheduledReminder(identifier: identifier(hour), title: hour.title, hour: reminder.hour, minute: reminder.minute)
        }
    }

    /// The Settings row's value: *Off*, *1 hour*, *3 hours*.
    static func summary(_ reminders: [String: HourReminder]) -> String {
        let count = rows.filter { reminders[$0.key]?.isOn == true }.count
        return switch count {
        case 0: "Off"
        case 1: "1 hour"
        default: "\(count) hours"
        }
    }
}

extension OfficeHour {
    /// The hour a key names (`OfficeHour.key`): a `CanonicalHour`'s raw name, or
    /// `martyrologium`.
    init?(key: String) {
        if key == OfficeHour.martyrologium.key {
            self = .martyrologium
        } else if let hour = CanonicalHour(rawValue: key) {
            self = .hour(hour)
        } else {
            return nil
        }
    }
}
