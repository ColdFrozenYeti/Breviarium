import BreviariumKit

/// What the hour picker opens (Beta 4): one of the office's hours, or the Martyrology, an
/// "hour" of its own under every office (decided 2026-09-24).
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
        guard case .hour(let hour) = self else { return self }
        return .hour(officium.availableHour(for: hour))
    }
}
