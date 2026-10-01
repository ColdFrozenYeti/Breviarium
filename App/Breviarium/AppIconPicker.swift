import SwiftUI
import UIKit

/// The Home Screen icon (added 1 October 2026): the original illuminated B, or the user's
/// second design (`Assets.xcassets/AppIconAlt.appiconset`). iOS remembers the choice
/// itself, so nothing is stored here.
///
/// UIKit exception: SwiftUI has no API for an app's alternate icon, so this view makes the
/// one UIKit call, `UIApplication.setAlternateIconName`, and nothing else. Alternate icons
/// need no entitlement, so a free Apple ID signs them (`CLAUDE.md`).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case original
    case alternative

    var id: Self { self }

    /// The asset catalog's icon set, `nil` for the primary icon.
    var iconName: String? {
        switch self {
        case .original: nil
        case .alternative: "AppIconAlt"
        }
    }

    var label: String {
        switch self {
        case .original: "Original"
        case .alternative: "Alternative"
        }
    }

    static var current: AppIconChoice {
        UIApplication.shared.alternateIconName == nil ? .original : .alternative
    }
}

struct AppIconPicker: View {
    @State private var choice = AppIconChoice.current

    var body: some View {
        Picker("Icon", selection: $choice) {
            ForEach(AppIconChoice.allCases) { icon in
                Text(icon.label).tag(icon)
            }
        }
        .accessibilityIdentifier("appIconPicker")
        .disabled(!UIApplication.shared.supportsAlternateIcons)
        .onChange(of: choice) { _, newChoice in
            guard newChoice.iconName != UIApplication.shared.alternateIconName else { return }
            Task { @MainActor in
                do {
                    try await UIApplication.shared.setAlternateIconName(newChoice.iconName)
                } catch {
                    choice = AppIconChoice.current
                }
            }
        }
    }
}
