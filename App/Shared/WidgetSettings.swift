import BreviariumKit
import Foundation

/// The settings the widgets follow (1.5, decided 2026-11-14): the app's own Ritus,
/// Officium, Psalterium, Theme and Font, which `SettingsStore` copies into the App Group
/// `group.com.epavone.breviarium` whenever they change, for the widget extension to read.
///
/// The App Group is in the TestFlight and App Store build only (`CLAUDE.md`, *No
/// capability a free Apple ID can't sign*). In the sideloaded build, which has no
/// entitlements and no widgets, the suite is just a local file nobody reads.
struct WidgetSettings: Equatable, Sendable {
    static let appGroup = "group.com.epavone.breviarium"

    var rite: Rite = .romanus
    var officium: Officium = .diei
    var psalter: Psalter = .vulgate
    var theme: ThemeChoice = .classicDark
    var font: FontChoice = .serif

    /// The app's own keys (`SettingsStore.Keys`), so the two can't drift apart in meaning.
    private enum Keys {
        static let rite = "settings.rite"
        static let officium = "settings.officium"
        static let psalter = "settings.psalter"
        static let theme = "settings.theme"
        static let font = "settings.font"
    }

    private static var suite: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// What the app last saved, or the app's defaults where it saved nothing.
    static func load() -> WidgetSettings {
        guard let defaults = suite else { return WidgetSettings() }
        var settings = WidgetSettings()
        if let value = defaults.string(forKey: Keys.rite).flatMap(Rite.init(rawValue:)) { settings.rite = value }
        if let value = defaults.string(forKey: Keys.officium).flatMap(Officium.init(rawValue:)) { settings.officium = value }
        if let value = defaults.string(forKey: Keys.psalter).flatMap(Psalter.init(rawValue:)) { settings.psalter = value }
        if let value = defaults.string(forKey: Keys.theme).flatMap(ThemeChoice.init(rawValue:)) { settings.theme = value }
        if let value = defaults.string(forKey: Keys.font).flatMap(FontChoice.init(rawValue:)) { settings.font = value }
        return settings
    }

    /// Writes these settings for the widgets; `true` when they differ from what was there.
    @discardableResult
    func save() -> Bool {
        guard let defaults = Self.suite, Self.load() != self else { return false }
        defaults.set(rite.rawValue, forKey: Keys.rite)
        defaults.set(officium.rawValue, forKey: Keys.officium)
        defaults.set(psalter.rawValue, forKey: Keys.psalter)
        defaults.set(theme.rawValue, forKey: Keys.theme)
        defaults.set(font.rawValue, forKey: Keys.font)
        return true
    }
}
