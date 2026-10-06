import SwiftUI
import UIKit

/// The Home Screen icon (added 1 October 2026; four icons since 6 October): the user's
/// designs, each an icon set in `Assets.xcassets` with a small `IconPreview…` image beside
/// it, since SwiftUI can't draw an app icon set. iOS remembers the choice itself, so
/// nothing is stored here.
///
/// UIKit exception: SwiftUI has no API for an app's alternate icon, so this file makes the
/// one UIKit call, `UIApplication.setAlternateIconName`, and nothing else. Alternate icons
/// need no entitlement, so a free Apple ID signs them (`CLAUDE.md`).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard
    case benedictus
    case gutenbergMono
    case gutenberg

    var id: Self { self }

    /// The asset catalog's icon set, `nil` for the primary icon. Each alternate one is
    /// listed in `project.yml`'s `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
    var iconName: String? {
        switch self {
        case .standard: nil
        case .benedictus: "AppIconBenedictus"
        case .gutenbergMono: "AppIconGutenbergMono"
        case .gutenberg: "AppIconGutenberg"
        }
    }

    /// The preview drawn in the gallery.
    var previewName: String {
        switch self {
        case .standard: "IconPreviewDefault"
        case .benedictus: "IconPreviewBenedictus"
        case .gutenbergMono: "IconPreviewGutenbergMono"
        case .gutenberg: "IconPreviewGutenberg"
        }
    }

    var label: String {
        switch self {
        case .standard: "Default"
        case .benedictus: "Benedictus"
        case .gutenbergMono: "Gutenberg (mono)"
        case .gutenberg: "Gutenberg"
        }
    }

    /// An icon name iOS remembers but the app no longer has reads as the default.
    static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standard
    }
}

/// The Settings row: the current icon's name, opening the gallery.
struct AppIconRow: View {
    @State private var current = AppIconChoice.current

    var body: some View {
        NavigationLink {
            AppIconGallery(current: $current)
        } label: {
            HStack {
                Text("Icon")
                    .foregroundStyle(Theme.liturgicalText)
                Spacer()
                Text(current.label)
                    .font(.footnote)
                    .foregroundStyle(Theme.chrome)
            }
        }
        .accessibilityIdentifier("appIconPicker")
        .disabled(!UIApplication.shared.supportsAlternateIcons)
        .onAppear { current = AppIconChoice.current }
    }
}

/// Every icon at once, two to a row, as it looks on the Home Screen; a tap chooses one.
struct AppIconGallery: View {
    @Binding var current: AppIconChoice
    private let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(AppIconChoice.allCases) { icon in
                    tile(icon)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Theme.background)
        .navigationTitle("App icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ icon: AppIconChoice) -> some View {
        let selected = icon == current
        return Button {
            choose(icon)
        } label: {
            VStack(spacing: 10) {
                Image(icon.previewName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityHidden(true)
                    // The Home Screen's rounded square (a continuous corner of about 22%).
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(selected ? Theme.icon : .clear, lineWidth: 3)
                    }
                HStack(spacing: 6) {
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.icon)
                            .accessibilityHidden(true)
                    }
                    Text(icon.label)
                        .foregroundStyle(selected ? Theme.liturgicalText : Theme.chrome)
                }
                .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.label)
        .accessibilityIdentifier("appIcon-\(icon.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choose(_ icon: AppIconChoice) {
        guard icon != current, UIApplication.shared.supportsAlternateIcons else { return }
        let previous = current
        current = icon
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(icon.iconName)
            } catch {
                current = previous
            }
        }
    }
}
