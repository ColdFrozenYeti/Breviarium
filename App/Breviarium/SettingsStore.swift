import BreviariumKit
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
/// How the office moves: book-style horizontal pages (the default, per `CLAUDE.md`'s
/// "swipes horizontally between pages") or one continuous vertical scroll.
enum ReadingMode: String, CaseIterable {
    case horizontal, vertical
}

/// How a horizontal page turns: a sideways slide, or a book-like page curl.
enum PageTurn: String, CaseIterable {
    case slide, curl
}

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
    @Published var readingMode: ReadingMode {
        didSet { defaults.set(readingMode.rawValue, forKey: Keys.readingMode) }
    }
    @Published var pageTurn: PageTurn {
        didSet { defaults.set(pageTurn.rawValue, forKey: Keys.pageTurn) }
    }
    /// The Vulgate by default, the Pius XII (Bea) psalter as an option (`CLAUDE.md`).
    @Published var psalter: Psalter {
        didSet { defaults.set(psalter.rawValue, forKey: Keys.psalter) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let priestPresent = "settings.priestPresent"
        static let showRubrics = "settings.showRubrics"
        static let showEnglish = "settings.showEnglish"
        static let textSize = "settings.textSize"
        static let readingMode = "settings.readingMode"
        static let pageTurn = "settings.pageTurn"
        static let psalter = "settings.psalter"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `bool(forKey:)` rather than `as? Bool`: a UI test's `-key YES` launch argument
        // arrives as the string "YES", which only `bool(forKey:)` reads as true.
        func bool(_ key: String, default value: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
        }
        priestPresent = bool(Keys.priestPresent, default: false)
        showRubrics = bool(Keys.showRubrics, default: true)
        showEnglish = bool(Keys.showEnglish, default: false)
        let storedRaw = defaults.string(forKey: Keys.textSize)
        textSize = storedRaw.flatMap { raw in TextSizeSetting.allCases.first { $0.rawValue == raw } } ?? .standard
        readingMode = defaults.string(forKey: Keys.readingMode).flatMap(ReadingMode.init(rawValue:)) ?? .horizontal
        pageTurn = defaults.string(forKey: Keys.pageTurn).flatMap(PageTurn.init(rawValue:)) ?? .slide
        psalter = defaults.string(forKey: Keys.psalter).flatMap(Psalter.init(rawValue:)) ?? .vulgate
    }
}
