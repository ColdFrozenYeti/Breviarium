import SwiftUI
import BreviariumKit

/// M0 placeholder: proves the repo -> Kit -> app -> unsigned .ipa -> sideload pipeline
/// end to end. Real views (Today/Vespers, TOC, date picker, Settings) land in M5.
struct ContentView: View {
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
            }
        }
    }
}

#Preview {
    ContentView()
}
