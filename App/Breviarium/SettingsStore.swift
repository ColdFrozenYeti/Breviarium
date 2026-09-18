import Foundation

/// `CLAUDE.md`'s "Settings (Universalis-style toggles)" -- `UserDefaults`-backed, since
/// this is a single-user, fully offline app with no iCloud entitlement a free Apple ID
/// could sign anyway (`CLAUDE.md`'s "No capability a free Apple ID can't sign").
///
/// Defaults picked to match what the rest of the codebase already assumed before this
/// store existed: `priestPresent = false` (every existing `HourAssembler`/`OfficeDataStore`
/// call site defaults `priest: false`), `showRubrics = true` and `showEnglish = false`
/// (`VespersView`'s own previous hardcoded values), `textSize = .standard` (what
/// `design/reference/Format.png` was measured at).
@MainActor
final class SettingsStore: ObservableObject {
    @Published var priestPresent: Bool {
        didSet { defaults.set(priestPresent, forKey: Keys.priestPresent) }
    }
    @Published var showRubrics: Bool {
        didSet { defaults.set(showRubrics, forKey: Keys.showRubrics) }
    }
    @Published var showEnglish: Bool {
        didSet { defaults.set(showEnglish, forKey: Keys.showEnglish) }
    }
    @Published var textSize: TextSizeSetting {
        didSet { defaults.set(textSize.rawValue, forKey: Keys.textSize) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let priestPresent = "settings.priestPresent"
        static let showRubrics = "settings.showRubrics"
        static let showEnglish = "settings.showEnglish"
        static let textSize = "settings.textSize"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        priestPresent = defaults.object(forKey: Keys.priestPresent) as? Bool ?? false
        showRubrics = defaults.object(forKey: Keys.showRubrics) as? Bool ?? true
        showEnglish = defaults.object(forKey: Keys.showEnglish) as? Bool ?? false
        let storedRaw = defaults.string(forKey: Keys.textSize)
        textSize = storedRaw.flatMap { raw in TextSizeSetting.allCases.first { $0.rawValue == raw } } ?? .standard
    }
}
