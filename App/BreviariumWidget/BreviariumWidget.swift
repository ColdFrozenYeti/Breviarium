import AppIntents
import BreviariumKit
import CoreText
import SwiftUI
import WidgetKit

// The widget extension (1.5, `docs/1.5_plan.md`): only in the TestFlight and App Store
// build (`build-ipa.yml` strips it from the sideloaded one). It has no App Group, so it
// can't read the app's settings: each widget has its own, under Edit Widget (§1.3).

@main
struct BreviariumWidgets: WidgetBundle {
    var body: some Widget {
        DayWidget()
        HourWidget()
        LockWidget()
    }
}

struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BreviariumDay", intent: BreviariumWidgetIntent.self, provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .day)
        }
        .configurationDisplayName("Dies")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HourWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BreviariumHour", intent: BreviariumWidgetIntent.self, provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .hour)
        }
        .configurationDisplayName("Hora")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BreviariumLock", intent: BreviariumWidgetIntent.self, provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .lock)
        }
        .configurationDisplayName("Hora")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// MARK: Edit Widget

enum WidgetRitus: String, AppEnum {
    case romanus, dominicanus, ambrosianus

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ritus"
    static let caseDisplayRepresentations: [WidgetRitus: DisplayRepresentation] = [
        .romanus: "Romanus", .dominicanus: "Dominicanus", .ambrosianus: "Ambrosianus",
    ]
}

enum WidgetOfficium: String, AppEnum {
    case diei, parvumBMV, defunctorum

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Officium"
    static let caseDisplayRepresentations: [WidgetOfficium: DisplayRepresentation] = [
        .diei: "Officium diei", .parvumBMV: "Officium parvum B.M.V.", .defunctorum: "Officium defunctorum",
    ]
}

enum WidgetPsalterium: String, AppEnum {
    case vulgate, pius12

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Psalterium"
    static let caseDisplayRepresentations: [WidgetPsalterium: DisplayRepresentation] = [
        .vulgate: "Vulgata", .pius12: "Pii XII",
    ]
}

enum WidgetTheme: String, AppEnum {
    case classicDark, midnightBlue, charcoal, light, sepia, vellum, forest, rose

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"
    // Literal, as App Intents' metadata extraction needs; the names are `ThemeChoice.name`.
    static let caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .classicDark: "Nox", .midnightBlue: "Media nox", .charcoal: "Carbo", .light: "Lux",
        .sepia: "Sepia", .vellum: "Vellum", .forest: "Silva", .rose: "Rosa",
    ]

    var choice: ThemeChoice { ThemeChoice(rawValue: rawValue) ?? .classicDark }
}

enum WidgetFont: String, AppEnum {
    case serif, gentium, sans, sourceSans, typewriter, comic

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Font"
    // Literal, as App Intents' metadata extraction needs; the names are `FontChoice.name`.
    static let caseDisplayRepresentations: [WidgetFont: DisplayRepresentation] = [
        .serif: "Hoefler Text", .gentium: "Gentium Book Plus", .sans: "SF Pro", .sourceSans: "Source Sans 3",
        .typewriter: "IBM Plex Mono", .comic: "Comic Neue",
    ]

    var choice: FontChoice { FontChoice(rawValue: rawValue) ?? .serif }
}

struct BreviariumWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Breviarium"

    @Parameter(title: "Ritus", default: .romanus) var ritus: WidgetRitus
    @Parameter(title: "Officium", default: .diei) var officium: WidgetOfficium
    @Parameter(title: "Psalterium", default: .vulgate) var psalterium: WidgetPsalterium
    @Parameter(title: "Theme", default: .classicDark) var theme: WidgetTheme
    @Parameter(title: "Font", default: .serif) var font: WidgetFont

    var rite: Rite { Rite(rawValue: ritus.rawValue) ?? .romanus }
    var office: Officium { Officium(rawValue: officium.rawValue) ?? .diei }
    var psalter: Psalter { Psalter(rawValue: psalterium.rawValue) ?? .vulgate }
}

// MARK: Timeline

struct BreviariumEntry: TimelineEntry {
    let date: Date
    let day: WidgetDay?
    let theme: ThemeChoice
    let font: FontChoice
}

/// The data, loaded once per process from the app's own bundle, which contains this
/// extension (`…/Breviarium.app/PlugIns/BreviariumWidget.appex`), with the app's fonts.
enum WidgetStore {
    static let appBundleURL: URL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()

    static let office: WidgetOffice? = {
        registerFonts()
        return WidgetData.office(inBundleAt: appBundleURL) ?? WidgetData.office(inBundleAt: Bundle.main.bundleURL)
    }()

    /// The app's bundled OFL fonts (`UIAppFonts` covers the app only), registered for this
    /// process from the app's bundle, so they ship once.
    private static func registerFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: appBundleURL, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "ttf" || url.pathExtension == "otf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct BreviariumProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BreviariumEntry {
        BreviariumEntry(date: Date(), day: nil, theme: .classicDark, font: .serif)
    }

    func snapshot(for configuration: BreviariumWidgetIntent, in context: Context) async -> BreviariumEntry {
        entries(for: configuration, at: Date()).last { $0.date <= Date() } ?? placeholder(in: context)
    }

    func timeline(for configuration: BreviariumWidgetIntent, in context: Context) async -> Timeline<BreviariumEntry> {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        return Timeline(entries: entries(for: configuration, at: now), policy: .after(tomorrow.addingTimeInterval(60)))
    }

    /// Today's entries, local time: one from each clock hour at which the hour changes
    /// (`WidgetOffice.timeline`, decided 2026-11-14).
    private func entries(for configuration: BreviariumWidgetIntent, at now: Date) -> [BreviariumEntry] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let office = WidgetStore.office, let d = today.day, let m = today.month, let y = today.year else {
            return [BreviariumEntry(date: now, day: nil, theme: configuration.theme.choice, font: configuration.font.choice)]
        }
        return office.timeline(day: d, month: m, year: y, rite: configuration.rite, officium: configuration.office, psalter: configuration.psalter)
            .map { item in
                let start = calendar.date(bySettingHour: item.clockHour, minute: 0, second: 0, of: now) ?? now
                return BreviariumEntry(date: start, day: item.entry, theme: configuration.theme.choice, font: configuration.font.choice)
            }
    }
}

// MARK: The view

struct BreviariumWidgetView: View {
    enum Kind { case day, hour, lock }

    let entry: BreviariumEntry
    let kind: Kind
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var layout: WidgetLayout {
        switch (kind, family) {
        case (.day, .systemMedium): .dayMedium
        case (.day, _): .daySmall
        case (.hour, .systemLarge): .hourLarge
        case (.hour, _): .hourMedium
        case (.lock, .accessoryInline): .lockInline
        case (.lock, .accessoryCircular): .lockCircular
        case (.lock, _): .lockRectangular
        }
    }

    var body: some View {
        let theme = entry.theme.theme
        WidgetFace(
            day: entry.day, layout: layout, theme: theme, font: entry.font,
            look: renderingMode == .fullColor && !layout.isLockScreen ? .fullColor : .tinted
        )
        .widgetURL(entry.day.flatMap(WidgetData.link(for:)))
        .containerBackground(for: .widget) {
            if layout.isLockScreen { Color.clear } else { theme.background }
        }
    }
}
