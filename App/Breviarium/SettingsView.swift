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
                    // The office is chosen under the rite (Beta 4, decided 2026-09-26; the
                    // Dominican office, Beta 5; Ambrosian Compline, Beta 6).
                    ForEach([Rite.romanus, .dominicanus, .ambrosianus], id: \.self) { rite in
                        NavigationLink {
                            OfficiumView(settings: settings, rite: rite)
                        } label: {
                            HStack {
                                Text(OfficiumView.name(of: rite))
                                    .foregroundStyle(Theme.liturgicalText)
                                Spacer()
                                if settings.rite == rite {
                                    Text(OfficiumView.label(for: settings.officium, rite: rite))
                                        .font(.footnote)
                                        .foregroundStyle(Theme.chrome)
                                }
                            }
                        }
                        .accessibilityIdentifier("ritus\(OfficiumView.name(of: rite))")
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
                } footer: {
                    // Beta 6: Ambrosian Compline is Latin only, in its own psalter.
                    if settings.rite == .ambrosianus {
                        Text("Completorium Ambrosianum is in Latin only, with the Ambrosian psalter.")
                            .foregroundStyle(Theme.chrome)
                    }
                }
                .disabled(settings.rite == .ambrosianus)

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

                Section("App icon") {
                    AppIconRow()
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

/// A rite's offices (Beta 4; Beta 5 for *Dominicanus*): the day's office is the default;
/// the other two are the votive offices the breviary provides. Choosing one chooses the
/// rite too.
struct OfficiumView: View {
    @ObservedObject var settings: SettingsStore
    let rite: Rite

    static func name(of rite: Rite) -> String {
        switch rite {
        case .romanus: "Romanus"
        case .dominicanus: "Dominicanus"
        case .ambrosianus: "Ambrosianus"
        }
    }

    /// The offices under a rite. *Ambrosianus* names only the one that exists
    /// (`CLAUDE.md`, decided 2026-10-01): Compline, under the day's office.
    static func offices(of rite: Rite) -> [Officium] {
        rite == .ambrosianus ? [.diei] : Officium.allCases
    }

    static func label(for officium: Officium, rite: Rite = .romanus) -> String {
        if rite == .ambrosianus { return "Completorium Ambrosianum" }
        return switch officium {
        case .diei: "Officium diei"
        case .parvumBMV: "Officium parvum B.M.V."
        case .defunctorum: "Officium defunctorum"
        }
    }

    var body: some View {
        List {
            Section("Officium") {
                ForEach(Self.offices(of: rite), id: \.self) { officium in
                    Button {
                        settings.rite = rite
                        settings.officium = officium
                    } label: {
                        HStack {
                            Text(Self.label(for: officium, rite: rite))
                                .foregroundStyle(Theme.liturgicalText)
                            Spacer()
                            if settings.rite == rite, settings.officium == officium {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.icon)
                            }
                        }
                    }
                    .accessibilityIdentifier("officium-\(officium.rawValue)")
                }
            }
        }
        .navigationTitle(Self.name(of: rite))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
