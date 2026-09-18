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

                // Disabled rather than removed: the underlying data is already there
                // (OfficeDataStore loads the English corpus unconditionally), but
                // VespersView doesn't render the parallel Latin/English layout
                // CLAUDE.md's spec calls for yet -- deferred to the beta milestones, per
                // direct feedback, rather than half-built now. A live toggle that
                // visibly changed nothing would be more confusing than an honest "not
                // yet" label.
                Section {
                    HStack {
                        Text("English translation")
                        Spacer()
                        Text("Coming in beta")
                            .font(.footnote)
                    }
                    .foregroundStyle(Theme.chrome)
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
