import SwiftUI
import BreviariumKit

/// M0/M5-in-progress placeholder: proves the repo -> Kit -> bundled data -> app ->
/// unsigned .ipa -> sideload pipeline end to end, including that the app can actually
/// load the bundle and assemble a real Vespers. The real, styled views (Today/Vespers
/// per `CLAUDE.md`'s visual spec, TOC, date picker, Settings) are still to come in M5 --
/// this is deliberately unstyled so it isn't mistaken for that design work.
struct ContentView: View {
    private let dataStore = OfficeDataStore()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Breviarium")
                    .font(.title)
                    .foregroundStyle(.white)
                Text("Kit data format v\(breviariumKitDataFormatVersion)")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.7, green: 0.7, blue: 0.7))
                Text(vespersSmokeTestSummary)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.7, green: 0.7, blue: 0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var vespersSmokeTestSummary: String {
        guard let hour = dataStore.vespers(on: Date(), priest: false) else {
            return "Vespers: bundled data not found"
        }
        let unitCount = hour.sections.reduce(0) { $0 + $1.units.count }
        return "Vespers loaded: \(hour.sections.count) sections, \(unitCount) units"
    }
}

#Preview {
    ContentView()
}
