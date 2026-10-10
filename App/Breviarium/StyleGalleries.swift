import BreviariumKit
import SwiftUI
import UIKit

/// The Theme and Font choices (1.2-M3, `docs/1.2_plan.md` §4): a Settings row showing the
/// current one, opening a gallery laid out like `AppIconGallery` -- two tiles to a row, all
/// at once, the name under each, the current one ringed with a checkmark; a tap chooses.
/// Each tile is the same fixed sample (`GallerySample`), set by the office's own
/// typesetter: the Theme page shows each theme in the current font, the Font page each
/// font in the current theme.
struct StyleRow<Gallery: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let value: String
    let identifier: String
    @ViewBuilder let gallery: () -> Gallery

    var body: some View {
        NavigationLink {
            gallery()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(theme.liturgicalText)
                Spacer()
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(theme.chrome)
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

struct ThemeGallery: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        StyleGallery(title: "Theme", choices: ThemeChoice.allCases, current: settings.theme, identifier: { "theme-\($0.rawValue)" }) { choice in
            (choice.name, OfficeTypesetter.sampleImage(sample, typeface: settings.font, theme: choice.theme))
        } choose: { settings.theme = $0 }
    }

    @Environment(\.gallerySample) private var sample
}

struct FontGallery: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        StyleGallery(title: "Font", choices: FontChoice.allCases, current: settings.font, identifier: { "font-\($0.rawValue)" }) { choice in
            (choice.name, OfficeTypesetter.sampleImage(sample, typeface: choice, theme: settings.theme.theme))
        } choose: { settings.font = $0 }
    }

    @Environment(\.gallerySample) private var sample
}

/// The grid both galleries share.
struct StyleGallery<Choice: Hashable>: View {
    @Environment(\.theme) private var theme
    let title: String
    let choices: [Choice]
    let current: Choice
    let identifier: (Choice) -> String
    let tile: (Choice) -> (name: String, image: UIImage)
    let choose: (Choice) -> Void

    private let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
    /// The tile's corner, about the icon tiles' (34 pt on a tile of about 160).
    private let corner: CGFloat = 30

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(choices, id: \.self) { choice in
                    tileView(choice)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tileView(_ choice: Choice) -> some View {
        let selected = choice == current
        let (name, image) = tile(choice)
        return Button {
            choose(choice)
        } label: {
            VStack(spacing: 10) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(OfficeTypesetter.sampleTileSize, contentMode: .fit)
                    .accessibilityHidden(true)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay {
                        // A hairline edge, so a tile whose background is the page's own
                        // (a light theme on a light page) still reads as a tile.
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(selected ? theme.icon : theme.chrome.opacity(0.35), lineWidth: selected ? 3 : 0.5)
                    }
                HStack(spacing: 6) {
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(theme.icon)
                            .accessibilityHidden(true)
                    }
                    Text(name)
                        .foregroundStyle(selected ? theme.liturgicalText : theme.chrome)
                }
                .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityIdentifier(identifier(choice))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
