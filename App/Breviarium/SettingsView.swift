import BreviariumKit
import SwiftUI

/// `CLAUDE.md`'s "Settings (Universalis-style toggles)" screen. Night mode only, like the
/// rest of the app -- `.preferredColorScheme(.dark)` rather than trusting the system
/// scheme, since there is no light theme to fall back to.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

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
                }

                Section {
                    Toggle("English translation", isOn: $settings.showEnglish)
                        .accessibilityIdentifier("englishToggle")
                    // Latin labels, like the other toggles (Beta 1 open question 1).
                    Picker("Psalterium", selection: $settings.psalter) {
                        Text("Vulgata").tag(Psalter.vulgate)
                        Text("Pii XII").tag(Psalter.pius12)
                    }
                    .accessibilityIdentifier("psalterPicker")
                }

                Section("Reading") {
                    Picker("Scrolling", selection: $settings.readingMode) {
                        Text("Horizontal").tag(ReadingMode.horizontal)
                        Text("Vertical").tag(ReadingMode.vertical)
                    }
                    .accessibilityIdentifier("readingModePicker")
                    Picker("Page turn", selection: $settings.pageTurn) {
                        Text("Slide").tag(PageTurn.slide)
                        Text("Page curl").tag(PageTurn.curl)
                    }
                    .disabled(settings.readingMode == .vertical)
                    .accessibilityIdentifier("pageTurnPicker")
                }

                Section("Text size") {
                    Picker("Text size", selection: $settings.textSize) {
                        ForEach(TextSizeSetting.allCases, id: \.self) { size in
                            Text(Self.label(for: size)).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    NavigationLink("About") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
