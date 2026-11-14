#if DEBUG
import BreviariumKit
import SwiftUI
import UIKit

/// The widgets as the UI tests photograph them (1.5, `docs/1.5_plan.md` §4): CI can't
/// place a widget on a simulator's Home Screen, so this debug-only screen draws the
/// widgets' own faces (`WidgetFace`) at the device's widget sizes, from the same data
/// file the widget reads. Opened by `BREVIARIUM_WIDGET_GALLERY` (`day`, `hour`, `lock`
/// or `tinted`), on `BREVIARIUM_SNAPSHOT_DATE` at the clock hour
/// `BREVIARIUM_WIDGET_CLOCK`, configured like the app's settings (Ritus, Officium,
/// Psalterium, Theme, Font).
struct WidgetGalleryView: View {
    let page: String
    let date: SimpleDate
    let clockHour: Int
    @StateObject private var settings = SettingsStore()

    private static let office = WidgetData.office(inBundleAt: Bundle.main.bundleURL)

    private var day: WidgetDay? {
        Self.office?.day(
            CanonicalHour.forTimeOfDay(clockHour: clockHour), day: date.day, month: date.month, year: date.year,
            rite: settings.rite, officium: settings.officium, psalter: settings.psalter
        )
    }

    var body: some View {
        let sizes = WidgetSizes.current
        VStack(spacing: 18) {
            switch page {
            case "hour":
                tile(.hourMedium, sizes.medium)
                tile(.hourLarge, sizes.large)
            case "lock":
                lock(.lockInline, sizes.inline)
                lock(.lockRectangular, sizes.rectangular)
                lock(.lockCircular, sizes.circular)
            case "tinted":
                tile(.daySmall, CGSize(width: sizes.small, height: sizes.small), look: .tinted)
                tile(.dayMedium, sizes.medium, look: .tinted)
                tile(.hourMedium, sizes.medium, look: .tinted)
            default:
                tile(.daySmall, CGSize(width: sizes.small, height: sizes.small))
                tile(.dayMedium, sizes.medium)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A plain wallpaper, so each widget's edge shows.
        .background(Color(red: 0.24, green: 0.25, blue: 0.29).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("widgetGallery")
    }

    /// A Home Screen widget: its background, the system's corner radius and content
    /// margins (16 points on iPhone and iPad).
    private func tile(_ layout: WidgetLayout, _ size: CGSize, look: WidgetLook = .fullColor) -> some View {
        let theme = settings.theme.theme
        return WidgetFace(day: day, layout: layout, theme: theme, font: settings.font, look: look)
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(look == .fullColor ? theme.background : Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityIdentifier("widget-\(layout.rawValue)")
    }

    /// A Lock Screen widget: no background or margins, drawn white as the system tints it.
    private func lock(_ layout: WidgetLayout, _ size: CGSize) -> some View {
        WidgetFace(day: day, layout: layout, theme: settings.theme.theme, font: settings.font, look: .tinted)
            .frame(width: size.width, height: size.height, alignment: layout == .lockInline ? .center : .leading)
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [3])))
            .accessibilityIdentifier("widget-\(layout.rawValue)")
    }
}

/// The widget sizes in points, by screen width, from Apple's Human Interface Guidelines
/// (*Widgets*, *Specifications*). The 402-point iPhones (iPhone 17) aren't in the table
/// we have; theirs are interpolated between the 393- and 414-point rows, so they may be a
/// point or two off the phone's.
struct WidgetSizes {
    var small: CGFloat
    var medium: CGSize
    var large: CGSize
    var circular: CGSize
    var rectangular: CGSize
    var inline: CGSize

    @MainActor static var current: WidgetSizes {
        let screen = UIScreen.main.bounds.size
        let width = min(screen.width, screen.height)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad Air 11" (M3) and the 820-point iPads.
            return WidgetSizes(
                small: 155, medium: CGSize(width: 342, height: 155), large: CGSize(width: 342, height: 342),
                circular: CGSize(width: 72, height: 72), rectangular: CGSize(width: 160, height: 72), inline: CGSize(width: 234, height: 26)
            )
        }
        switch width {
        case 428...:
            return WidgetSizes(
                small: 170, medium: CGSize(width: 364, height: 170), large: CGSize(width: 364, height: 382),
                circular: CGSize(width: 76, height: 76), rectangular: CGSize(width: 172, height: 76), inline: CGSize(width: 257, height: 26)
            )
        case 414...:
            return WidgetSizes(
                small: 169, medium: CGSize(width: 360, height: 169), large: CGSize(width: 360, height: 379),
                circular: CGSize(width: 76, height: 76), rectangular: CGSize(width: 172, height: 76), inline: CGSize(width: 257, height: 26)
            )
        case 400...:
            return WidgetSizes(
                small: 162, medium: CGSize(width: 345, height: 162), large: CGSize(width: 345, height: 363),
                circular: CGSize(width: 72, height: 72), rectangular: CGSize(width: 160, height: 72), inline: CGSize(width: 234, height: 26)
            )
        case 390...:
            return WidgetSizes(
                small: 158, medium: CGSize(width: 338, height: 158), large: CGSize(width: 338, height: 354),
                circular: CGSize(width: 72, height: 72), rectangular: CGSize(width: 160, height: 72), inline: CGSize(width: 234, height: 26)
            )
        default:
            return WidgetSizes(
                small: 155, medium: CGSize(width: 329, height: 155), large: CGSize(width: 329, height: 345),
                circular: CGSize(width: 72, height: 72), rectangular: CGSize(width: 160, height: 72), inline: CGSize(width: 234, height: 26)
            )
        }
    }
}
#endif
