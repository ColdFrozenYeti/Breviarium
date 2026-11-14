import BreviariumKit
import CoreText
import SwiftUI
import WidgetKit

// The widget extension (1.5, `docs/1.5_plan.md`): only in the TestFlight and App Store
// build (`build-ipa.yml` strips it from the sideloaded one). It follows the app's own
// Ritus, Officium, Psalterium, Theme and Font, which the app shares through the App Group
// (`WidgetSettings`, decided 2026-11-14); there is nothing to set under Edit Widget.

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
        StaticConfiguration(kind: "BreviariumDay", provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .day)
        }
        .configurationDisplayName("Dies")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HourWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreviariumHour", provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .hour)
        }
        .configurationDisplayName("Hora")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreviariumLock", provider: BreviariumProvider()) { entry in
            BreviariumWidgetView(entry: entry, kind: .lock)
        }
        .configurationDisplayName("Hora")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
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

struct BreviariumProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreviariumEntry {
        BreviariumEntry(date: Date(), day: nil, theme: .classicDark, font: .serif)
    }

    func getSnapshot(in context: Context, completion: @escaping (BreviariumEntry) -> Void) {
        let now = Date()
        completion(entries(at: now).last { $0.date <= now } ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreviariumEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        // The app reloads every timeline when a shared setting changes (`SettingsStore`).
        completion(Timeline(entries: entries(at: now), policy: .after(tomorrow.addingTimeInterval(60))))
    }

    /// Today's entries, local time, under the app's settings: one from each clock hour at
    /// which the hour changes (`WidgetOffice.timeline`, decided 2026-11-14).
    private func entries(at now: Date) -> [BreviariumEntry] {
        let settings = WidgetSettings.load()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let office = WidgetStore.office, let d = today.day, let m = today.month, let y = today.year else {
            return [BreviariumEntry(date: now, day: nil, theme: settings.theme, font: settings.font)]
        }
        return office.timeline(day: d, month: m, year: y, rite: settings.rite, officium: settings.officium, psalter: settings.psalter)
            .map { item in
                let start = calendar.date(bySettingHour: item.clockHour, minute: 0, second: 0, of: now) ?? now
                return BreviariumEntry(date: start, day: item.entry, theme: settings.theme, font: settings.font)
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
