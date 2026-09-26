import BreviariumKit

/// What the hour picker opens (Beta 4): one of the office's hours, or the Martyrology, an
/// "hour" of its own (decided 2026-09-24). It is read at Prime of the day's office, so it
/// follows Prime in the picker, and the Little Office and the Office of the Dead don't
/// have it: DO reads it from the Ordinarium's Prime, which the Little Office replaces
/// with its own (decided 2026-09-26).
enum OfficeHour: Hashable {
    case hour(CanonicalHour)
    case martyrologium

    /// The page and navigation title.
    var title: String {
        switch self {
        case .hour(let hour): hour.title
        case .martyrologium: "Martyrologium"
        }
    }

    /// A stable name, for keys and accessibility identifiers.
    var key: String {
        switch self {
        case .hour(let hour): hour.rawValue
        case .martyrologium: "martyrologium"
        }
    }

    /// The hour `officium` actually shows for this choice: an hour the office lacks opens
    /// the nearest earlier one it has (decided 2026-09-26).
    func shown(in officium: Officium) -> OfficeHour {
        switch self {
        case .hour(let hour): .hour(officium.availableHour(for: hour))
        case .martyrologium: officium == .diei ? self : .hour(officium.availableHour(for: .prima))
        }
    }

    /// The picker's rows: the office's hours, with the Martyrology after Prime in the
    /// day's office.
    static func rows(for officium: Officium) -> [OfficeHour] {
        officium.hours.flatMap { hour -> [OfficeHour] in
            officium == .diei && hour == .prima ? [.hour(hour), .martyrologium] : [.hour(hour)]
        }
    }
}
