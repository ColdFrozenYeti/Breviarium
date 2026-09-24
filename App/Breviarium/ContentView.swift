import SwiftUI
import BreviariumKit

/// The app's single screen: one hour of the Roman office for a given date (Beta 2: the
/// day hours, Lauds to Compline). Real content only -- no liturgical logic lives here,
/// every decision already happened inside `OfficeDataStore`'s `BreviariumKit` calls.
struct ContentView: View {
    enum DateSource {
        case now
        /// A specific day/month/year, bypassing `Date`/`Calendar` entirely -- used for
        /// deterministic UI-test snapshots (`BreviariumApp`'s `BREVIARIUM_SNAPSHOT_DATE`).
        case fixed(day: Int, month: Int, year: Int)
    }

    let dateSource: DateSource
    /// A section to open at (UI tests only; see `BreviariumApp`).
    let initialSection: String?
    /// The hour being shown: at launch the hour for the time of day (decided
    /// 2026-09-24), or `BREVIARIUM_SNAPSHOT_HOUR` in UI tests; then the hour picker's.
    @State private var canonicalHour: CanonicalHour

    private let dataStore = OfficeDataStore()
    @StateObject private var settings = SettingsStore()
    /// The date actually being shown -- starts at `dateSource`'s own date, then moves
    /// independently via the previous/next-day and jump-to-date controls (`VespersView`'s
    /// own doc comment covers why `SimpleDate`, not `Date`, is what those pass back).
    @State private var displayedDate: SimpleDate

    init(dateSource: DateSource = .now, initialSection: String? = nil, initialHour: CanonicalHour? = nil) {
        self.dateSource = dateSource
        self.initialSection = initialSection
        _canonicalHour = State(initialValue: initialHour ?? Self.hourForTimeOfDay(Date()))
        switch dateSource {
        case .now: _displayedDate = State(initialValue: .today())
        case .fixed(let day, let month, let year): _displayedDate = State(initialValue: SimpleDate(day: day, month: month, year: year))
        }
    }

    var body: some View {
        if let content = vespersContent {
            VespersView(
                content: content, settings: settings, canonicalHour: canonicalHour,
                onSelectHour: { canonicalHour = $0 },
                onPreviousDay: { displayedDate = SimpleDate(Computus.addDays(-1, day: displayedDate.day, month: displayedDate.month, year: displayedDate.year)) },
                onNextDay: { displayedDate = SimpleDate(Computus.addDays(1, day: displayedDate.day, month: displayedDate.month, year: displayedDate.year)) },
                onJump: { newDate in displayedDate = newDate },
                initialSection: initialSection
            )
        } else {
            ZStack {
                Theme.background.ignoresSafeArea()
                // Includes OfficeDataStore's own diagnostic string -- temporary, while
                // the bundling pipeline is still being shaken out (see its doc comment).
                Text("\(canonicalHour.title) could not be loaded for this date.\n\(dataStore.loadDiagnostic)")
                    .foregroundStyle(Theme.chrome)
                    .padding()
            }
        }
    }

    /// The hour for the time of day (decided 2026-09-24): Lauds until 09:00, Terce until
    /// 12:00, Sext until 15:00, None until 17:00, Vespers until 20:00, then Compline.
    /// Prime is reached from the picker.
    static func hourForTimeOfDay(_ date: Date, calendar: Calendar = .current) -> CanonicalHour {
        switch calendar.component(.hour, from: date) {
        case ..<9: .laudes
        case ..<12: .tertia
        case ..<15: .sexta
        case ..<17: .nona
        case ..<20: .vesperae
        default: .completorium
        }
    }

    private var vespersContent: VespersContent? {
        dataStore.content(
            for: canonicalHour, day: displayedDate.day, month: displayedDate.month, year: displayedDate.year, priest: settings.priestPresent,
            psalter: settings.psalter, english: settings.showEnglish
        )
    }
}

#Preview {
    ContentView()
}
