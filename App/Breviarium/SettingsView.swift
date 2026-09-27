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
                    // The office is chosen under the rite (Beta 4, decided 2026-09-26).
                    NavigationLink {
                        OfficiumView(settings: settings)
                    } label: {
                        HStack {
                            Text("Romanus")
                                .foregroundStyle(Theme.liturgicalText)
                            Spacer()
                            Text(OfficiumView.label(for: settings.officium))
                                .font(.footnote)
                                .foregroundStyle(Theme.chrome)
                        }
                    }
                    .accessibilityIdentifier("ritusRomanus")
                    // Shown but not selectable until each rite is built.
                    ForEach(["Ambrosianus", "Dominicanus"], id: \.self) { rite in
                        HStack {
                            Text(rite)
                            Spacer()
                            Text("Coming soon")
                                .font(.footnote)
                        }
                        .foregroundStyle(Theme.chrome)
                    }
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
                    NavigationLink("Release notes") {
                        ReleaseNotesView()
                    }
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

/// *Ritus Romanus*: the office said (Beta 4). The day's office is the default; the other
/// two are the votive offices the Roman breviary provides.
struct OfficiumView: View {
    @ObservedObject var settings: SettingsStore

    static func label(for officium: Officium) -> String {
        switch officium {
        case .diei: "Officium diei"
        case .parvumBMV: "Officium parvum B.M.V."
        case .defunctorum: "Officium defunctorum"
        }
    }

    var body: some View {
        List {
            Section("Officium") {
                ForEach(Officium.allCases, id: \.self) { officium in
                    Button {
                        settings.officium = officium
                    } label: {
                        HStack {
                            Text(Self.label(for: officium))
                                .foregroundStyle(Theme.liturgicalText)
                            Spacer()
                            if settings.officium == officium {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.icon)
                            }
                        }
                    }
                    .accessibilityIdentifier("officium-\(officium.rawValue)")
                }
            }
        }
        .navigationTitle("Romanus")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
