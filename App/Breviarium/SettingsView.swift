import SwiftUI

/// `CLAUDE.md`'s "Settings (Universalis-style toggles)" screen. Night mode only, like the
/// rest of the app -- `.preferredColorScheme(.dark)` rather than trusting the system
/// scheme, since there is no light theme to fall back to.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section("Ritus") {
                    HStack {
                        Text("Romanus")
                            .foregroundStyle(Theme.liturgicalText)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.icon)
                    }
                    HStack {
                        Text("Ambrosianus")
                        Spacer()
                        Text("Coming later")
                            .font(.footnote)
                    }
                    .foregroundStyle(Theme.chrome)
                }

                Section {
                    Toggle("Sacerdos vel diaconus adest", isOn: $settings.priestPresent)
                    Toggle("Rubricæ", isOn: $settings.showRubrics)
                    Toggle("English translation", isOn: $settings.showEnglish)
                }

                Section("Text size") {
                    Picker("Text size", selection: $settings.textSize) {
                        ForEach(TextSizeSetting.allCases, id: \.self) { size in
                            Text(Self.label(for: size)).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
    }

    private static func label(for size: TextSizeSetting) -> String {
        switch size {
        case .small: "S"
        case .standard: "M"
        case .large: "L"
        case .extraLarge: "XL"
        case .largest: "XXL"
        }
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
