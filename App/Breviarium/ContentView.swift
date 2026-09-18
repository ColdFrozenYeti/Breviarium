import SwiftUI
import BreviariumKit

/// The app's single screen for now: Roman Vespers for a given date (`CLAUDE.md`: "The
/// alpha is Roman Vespers only"). Real content only -- no liturgical logic lives here,
/// every decision already happened inside `OfficeDataStore`'s `BreviariumKit` calls.
struct ContentView: View {
    enum DateSource {
        case now
        /// A specific day/month/year, bypassing `Date`/`Calendar` entirely -- used for
        /// deterministic UI-test snapshots (`BreviariumApp`'s `BREVIARIUM_SNAPSHOT_DATE`).
        case fixed(day: Int, month: Int, year: Int)
    }

    let dateSource: DateSource

    private let dataStore = OfficeDataStore()

    init(dateSource: DateSource = .now) {
        self.dateSource = dateSource
    }

    var body: some View {
        if let content = vespersContent {
            VespersView(content: content)
        } else {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text("Vespers could not be loaded for this date.")
                    .foregroundStyle(Theme.chrome)
                    .padding()
            }
        }
    }

    private var vespersContent: VespersContent? {
        switch dateSource {
        case .now:
            return dataStore.vespersContent(on: Date(), priest: false)
        case .fixed(let day, let month, let year):
            return dataStore.vespersContent(day: day, month: month, year: year, priest: false)
        }
    }
}

#Preview {
    ContentView()
}
