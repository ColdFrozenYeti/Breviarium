import BreviariumKit
import SwiftUI
import UIKit

/// The whole hour typeset once, as one attributed string, shared by every reading mode
/// (vertical scroll, horizontal pages with a slide or a page-curl turn) so they look
/// identical. `sectionOffsets` is where each section's separator begins, for the table
/// of contents.
struct TypesetOffice {
    let text: NSAttributedString
    let sectionOffsets: [(kind: BreviariumKit.Section.Kind, offset: Int)]
}

/// In-text controls on page 1: the date line (jump to date) and the table-of-contents
/// icon. Handled entirely inside the app by `OfficeLink.url(for:)`'s callers -- these
/// URLs are never opened, and the scheme is not registered, so nothing ever leaves the
/// app (`CLAUDE.md`: fully offline).
enum OfficeLink {
    static let scheme = "breviarium-internal"
    static let tableOfContents = URL(string: "breviarium-internal:toc")!
    static let jumpToDate = URL(string: "breviarium-internal:date")!

    /// The in-app link a tapped text item stands for, if it is one of ours.
    @MainActor
    static func url(for item: UITextItem) -> URL? {
        switch item.content {
        case .link(let url):
            return url.scheme == scheme ? url : nil
        case .textAttachment(let attachment):
            return attachment is TableOfContentsAttachment ? tableOfContents : nil
        default:
            return nil
        }
    }
}

/// The table-of-contents icon's attachment, told apart from the separator rules by type.
final class TableOfContentsAttachment: NSTextAttachment {}

/// Typesets one hour per `CLAUDE.md`'s visual spec (§ "Page structure", items 2-9).
///
/// UIKit/TextKit rather than SwiftUI `Text`, by explicit decision (`docs/PLAN.md`, M5):
/// book-style pagination needs the text to flow line by line from one page to the next
/// at any text size, which only TextKit's container chain can do, and the page-curl turn
/// exists only in `UIPageViewController`. Every style the earlier SwiftUI renderer
/// (`UnitView`) settled on through direct feedback is carried over here: bold-italic
/// antiphons, alternate psalm verses in italic, the red ✠ and ‡, indented italic
/// responses and second half-verses, stanza gaps, and the small rule between psalms.
@MainActor
struct OfficeTypesetter {
    let content: VespersContent
    let metrics: Metrics
    let showRubrics: Bool

    private var textColor: UIColor { UIColor(Theme.liturgicalText) }
    private var rubricColor: UIColor { UIColor(Theme.rubric) }
    private var iconColor: UIColor { UIColor(Theme.icon) }
    private var chromeColor: UIColor { UIColor(Theme.chrome) }

    func typeset() -> TypesetOffice {
        let output = NSMutableAttributedString()
        var offsets: [(kind: BreviariumKit.Section.Kind, offset: Int)] = []

        for block in ContentBlock.blocks(for: content.hour) {
            switch block {
            case .pageHeader:
                appendHeader(to: output)
            case .sectionStart(let kind):
                offsets.append((kind: kind, offset: output.length))
                appendRule(
                    to: output, width: metrics.separatorWidth, color: textColor,
                    before: metrics.separatorSpacingAbove, after: metrics.separatorSpacing
                )
                // 0.9x body below the heading: `Format.png` measures 26.7pt from the
                // heading to the first body line (0.6x gave 21pt).
                appendParagraph(
                    NSMutableAttributedString(
                        string: Self.headingText(for: kind),
                        attributes: [.font: LiturgicalUIFont.black(metrics.sectionHeadingSize), .foregroundColor: textColor]
                    ),
                    to: output, style: paragraphStyle(after: metrics.bodySize * 0.9)
                )
            case .psalmSeparator:
                appendRule(
                    to: output, width: metrics.separatorWidth * 0.4, color: textColor.withAlphaComponent(0.4),
                    before: metrics.bodySize * 0.5, after: metrics.bodySize * 0.5
                )
            case .unit(_, let unit, let alternateVerse, let trailingSpace):
                appendUnit(unit, alternateVerse: alternateVerse, trailingSpace: trailingSpace, to: output)
            }
        }

        // No empty line after the last paragraph (it would be a blank line on the last page).
        if output.string.hasSuffix("\n") {
            output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
        }
        return TypesetOffice(text: output, sectionOffsets: offsets)
    }

    static func headingText(for kind: BreviariumKit.Section.Kind) -> String {
        switch kind {
        case .introductio: "INTRODUCTIO"
        case .psalmodia: "PSALMODIA"
        case .capitulum: "CAPITULUM"
        case .hymnus: "HYMNUS"
        case .versus: "VERSUS"
        case .canticum: "CANTICUM"
        case .precesFeriales: "PRECES FERIALES"
        case .oratio: "ORATIO"
        case .conclusio: "CONCLUSIO"
        }
    }

    // MARK: Items 2-6 -- page 1's header

    private func appendHeader(to output: NSMutableAttributedString) {
        // Item 2: the date line, which is also the jump-to-date control.
        appendParagraph(
            NSMutableAttributedString(string: content.dateLine, attributes: [
                .font: UIFont.italicSystemFont(ofSize: metrics.dateLineSize),
                .foregroundColor: rubricColor,
                .link: OfficeLink.jumpToDate,
            ]),
            to: output, style: paragraphStyle(alignment: .right, after: metrics.bodySize * 0.8)
        )

        // Item 3: the day title block. Wrapped lines of the name take the hanging indent.
        let titleBlock = content.day.titleBlock
        if let classisLine = titleBlock.classisLine {
            appendParagraph(
                plain(classisLine, font: LiturgicalUIFont.regular(metrics.bodySize)),
                to: output, style: paragraphStyle(after: metrics.bodySize * 0.2)
            )
        }
        appendParagraph(
            plain(titleBlock.nameLine, font: LiturgicalUIFont.black(metrics.dayTitleNameSize)),
            to: output,
            style: paragraphStyle(
                headIndent: metrics.hangingIndent,
                after: titleBlock.commemorationLine == nil ? metrics.bodySize * 0.6 : metrics.bodySize * 0.2
            )
        )
        if let commemorationLine = titleBlock.commemorationLine {
            appendParagraph(
                plain(commemorationLine, font: LiturgicalUIFont.regular(metrics.bodySize)),
                to: output, style: paragraphStyle(after: metrics.bodySize * 0.6)
            )
        }

        // Item 4: the table-of-contents icon, right-aligned.
        let attachment = TableOfContentsAttachment()
        let configuration = UIImage.SymbolConfiguration(pointSize: metrics.bodySize, weight: .regular)
        attachment.image = UIImage(systemName: "list.bullet", withConfiguration: configuration)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)
        let icon = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        icon.addAttribute(.link, value: OfficeLink.tableOfContents, range: NSRange(location: 0, length: icon.length))
        // `Format.png` measures 12pt from the icon to the hour title (0.8x body gave 21pt).
        appendParagraph(icon, to: output, style: paragraphStyle(alignment: .right, after: metrics.bodySize * 0.33))

        // Item 5: the hour title, centred.
        appendParagraph(
            plain(content.hourTitle, font: LiturgicalUIFont.regular(metrics.hourTitleSize)),
            to: output, style: paragraphStyle(alignment: .center, after: metrics.bodySize * 0.8)
        )
    }

    // MARK: Item 9 -- body units

    private func appendUnit(
        _ unit: BreviariumKit.Unit, alternateVerse: Bool, trailingSpace: ContentBlock.TrailingSpace,
        to output: NSMutableAttributedString
    ) {
        let regular = LiturgicalUIFont.regular(metrics.bodySize)
        let italic = LiturgicalUIFont.italic(metrics.bodySize)
        let gap = trailingGap(trailingSpace)

        switch unit {
        case .rubric(let text, _):
            guard showRubrics else { return }
            appendParagraph(liturgical(text, font: italic, color: rubricColor), to: output, style: paragraphStyle(after: gap))
        case .versicleResponse(let versicle, let response, _, _):
            appendParagraph(liturgical(versicle, font: regular, color: textColor), to: output, style: paragraphStyle())
            appendParagraph(
                liturgical(response, font: italic, color: textColor), to: output,
                style: paragraphStyle(firstLineIndent: metrics.versicleIndent, headIndent: metrics.versicleIndent, after: gap)
            )
        case .verse(_, let firstHalf, let secondHalf, _, _):
            let font = alternateVerse ? italic : regular
            if secondHalf.isEmpty {
                appendParagraph(liturgical(firstHalf, font: font, color: textColor), to: output, style: paragraphStyle(after: gap))
            } else {
                appendParagraph(liturgical(firstHalf, font: font, color: textColor), to: output, style: paragraphStyle())
                appendParagraph(
                    liturgical(secondHalf, font: font, color: textColor), to: output,
                    style: paragraphStyle(firstLineIndent: metrics.versicleIndent, headIndent: metrics.versicleIndent, after: gap)
                )
            }
        case .antiphon(let text, _):
            // Extra room below an antiphon so it doesn't read as part of the psalm that
            // follows -- skipped before a psalm separator, whose own spacing is symmetric.
            let after = trailingSpace == .suppressed ? 0 : metrics.bodySize * 0.5
            appendParagraph(
                liturgical(text, font: LiturgicalUIFont.blackItalic(metrics.bodySize), color: textColor),
                to: output, style: paragraphStyle(after: after)
            )
        case .prose(let text, _):
            appendParagraph(liturgical(text, font: regular, color: textColor), to: output, style: paragraphStyle(after: gap))
        case .psalmTitle(let text):
            appendParagraph(
                liturgical(text, font: italic, color: chromeColor), to: output,
                style: paragraphStyle(after: metrics.bodySize * 0.3)
            )
        }
    }

    /// Extra space below a unit beyond the uniform line pitch (`Metrics.extraLineSpacing`,
    /// which every line already gets).
    private func trailingGap(_ trailingSpace: ContentBlock.TrailingSpace) -> CGFloat {
        switch trailingSpace {
        case .standard, .suppressed: 0
        case .stanzaBreak: metrics.bodySize * 0.6
        }
    }

    // MARK: Building blocks

    private func plain(_ text: String, font: UIFont) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
    }

    /// Liturgical text with DO's `+` shown as ✠, and the ✠ and a leading or trailing ‡
    /// (the antiphon/first-verse dagger) in the rubric colour -- they are rubrical
    /// gestures inside otherwise ordinary text.
    private func liturgical(_ raw: String, font: UIFont, color: UIColor) -> NSMutableAttributedString {
        let text = raw.replacingOccurrences(of: "+", with: "✠")
        let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.length > 0 {
            let found = nsText.range(of: "✠", options: [], range: searchRange)
            if found.location == NSNotFound { break }
            result.addAttribute(.foregroundColor, value: rubricColor, range: found)
            let next = NSMaxRange(found)
            searchRange = NSRange(location: next, length: nsText.length - next)
        }
        if text.hasPrefix("‡ ") {
            result.addAttribute(.foregroundColor, value: rubricColor, range: NSRange(location: 0, length: 1))
        }
        if text.hasSuffix(" ‡") {
            result.addAttribute(.foregroundColor, value: rubricColor, range: NSRange(location: nsText.length - 1, length: 1))
        }
        return result
    }

    private func paragraphStyle(
        alignment: NSTextAlignment = .left, firstLineIndent: CGFloat = 0, headIndent: CGFloat = 0,
        before: CGFloat = 0, after: CGFloat = 0, lineSpacing: CGFloat? = nil
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.firstLineHeadIndent = firstLineIndent
        style.headIndent = headIndent
        style.lineSpacing = lineSpacing ?? metrics.extraLineSpacing
        style.paragraphSpacingBefore = before
        style.paragraphSpacing = after
        style.lineBreakMode = .byWordWrapping
        return style
    }

    /// Appends `text` as one paragraph. The closing line break carries the paragraph's
    /// own attributes, so it never brings in a default font that would change the last
    /// line's height.
    ///
    /// Line breaks *inside* a unit (a hymn stanza's lines, from
    /// `HourAssembler.hymnStanzas`) become U+2028 LINE SEPARATOR first. TextKit starts a
    /// new paragraph at every `\n`, so a stanza with plain `\n`s turned into one paragraph
    /// per line, and the stanza gap (`paragraphSpacing`) landed after every line: hymns
    /// showed as evenly spaced single lines with no visible stanzas (B1-M0; the
    /// regression came in with the TextKit port, `2ef9957`). With line separators the
    /// stanza stays one paragraph: `lineSpacing` gives the normal pitch within it, and
    /// the gap applies once, after its last line.
    private func appendParagraph(_ text: NSMutableAttributedString, to output: NSMutableAttributedString, style: NSParagraphStyle) {
        text.mutableString.replaceOccurrences(
            of: "\n", with: "\u{2028}", options: [], range: NSRange(location: 0, length: text.length)
        )
        let breakAttributes = text.length > 0 ? text.attributes(at: text.length - 1, effectiveRange: nil) : [:]
        var cleanBreakAttributes = breakAttributes
        cleanBreakAttributes.removeValue(forKey: .link)
        cleanBreakAttributes.removeValue(forKey: .attachment)
        text.append(NSAttributedString(string: "\n", attributes: cleanBreakAttributes))
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        output.append(text)
    }

    /// Item 7: a centred horizontal rule (drawn as an image attachment on its own line).
    private func appendRule(to output: NSMutableAttributedString, width: CGFloat, color: UIColor, before: CGFloat, after: CGFloat) {
        let size = CGSize(width: max(1, width), height: 1)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        let rule = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        rule.addAttribute(.font, value: UIFont.systemFont(ofSize: 1), range: NSRange(location: 0, length: rule.length))
        appendParagraph(rule, to: output, style: paragraphStyle(alignment: .center, before: before, after: after, lineSpacing: 0))
    }
}

/// Remembers the last typeset hour so SwiftUI re-renders (a page change, a sheet
/// opening) reuse it instead of typesetting again -- and so the text views keep their
/// reading position, which they only reset when `key` changes.
@MainActor
final class TypesetCache {
    private var key = ""
    private var cached: TypesetOffice?

    func office(for key: String, build: () -> TypesetOffice) -> TypesetOffice {
        if key == self.key, let cached { return cached }
        let office = build()
        self.key = key
        cached = office
        return office
    }
}
