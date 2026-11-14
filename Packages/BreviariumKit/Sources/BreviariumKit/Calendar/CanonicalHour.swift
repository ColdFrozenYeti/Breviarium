/// The day hours of the Roman office (Beta 2), named as DO names them: `$hora`, the
/// `pray<Hour>` command (`officium.pl:142-144`) and the skeleton file under
/// `Ordinarium/`. Matins (`Matutinum`) joined in Beta 3.
public enum CanonicalHour: String, CaseIterable, Sendable, Codable {
    case matutinum = "Matutinum"
    case laudes = "Laudes"
    case prima = "Prima"
    case tertia = "Tertia"
    case sexta = "Sexta"
    case nona = "Nona"
    case vesperae = "Vespera"
    case completorium = "Completorium"

    /// DO's `$hora`: what `(sed ad …)` conditionals and the `ad` subject match against
    /// (`SetupString.pl:31`).
    public var doName: String { rawValue }

    /// The skeleton file, `Ordinarium/<name>.txt`: Terce, Sext and None share `Minor`.
    public var skeletonName: String {
        switch self {
        case .tertia, .sexta, .nona: "Minor"
        default: rawValue
        }
    }

    /// The page and navigation title, as DO heads the page (`Ad Tertiam`, …).
    public var title: String {
        switch self {
        case .matutinum: "Ad Matutinum"
        case .laudes: "Ad Laudes"
        case .prima: "Ad Primam"
        case .tertia: "Ad Tertiam"
        case .sexta: "Ad Sextam"
        case .nona: "Ad Nonam"
        case .vesperae: "Ad Vesperas"
        case .completorium: "Ad Completorium"
        }
    }

    /// Lauds and Vespers, DO's `$horamajor`: commemorations, the major psalmody and the
    /// Gospel canticle.
    public var isMajor: Bool { self == .laudes || self == .vesperae }

    /// Terce, Sext and None.
    public var isLittleHour: Bool { self == .tertia || self == .sexta || self == .nona }

    /// The hour the app opens at a time of day (decided 2026-09-24): Matins until 05:00,
    /// then Lauds, Terce, Sext, None, Vespers and Compline. `clockHour` is 0-23, local
    /// time. The app's launch and the widgets (1.5) both use it.
    public static func forTimeOfDay(clockHour: Int) -> CanonicalHour {
        switch clockHour {
        case ..<5: .matutinum
        case ..<9: .laudes
        case ..<12: .tertia
        case ..<15: .sexta
        case ..<17: .nona
        case ..<20: .vesperae
        default: .completorium
        }
    }

    /// The clock hours at which `forTimeOfDay` changes hour, midnight included: a widget's
    /// timeline has an entry at each.
    public static let timeOfDayBoundaries = [0, 5, 9, 12, 15, 17, 20]

    /// Vespers and Compline belong to the office whose Vespers is said that evening
    /// (`Concurrence`); the other hours to the day's own office (`Occurrence`).
    public var followsConcurrence: Bool { self == .vesperae || self == .completorium }
}
