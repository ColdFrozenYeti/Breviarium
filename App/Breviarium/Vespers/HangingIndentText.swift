import SwiftUI
import UIKit

/// A left-aligned, word-wrapping label with a hanging indent on continuation lines --
/// `CLAUDE.md`'s "Day title block" wants ~38pt on a wrapped feast/feria name's second
/// and later lines. Plain SwiftUI `Text` has no first-line-vs-continuation distinction
/// to express that. `CLAUDE.md` asks to flag before reaching for UIKit: confirmed
/// against a real rendering that the gap was visible and real, not just theoretical
/// (`VespersView`'s own history has the comparison) -- this is that considered
/// exception, using `NSParagraphStyle.headIndent`, the standard technique for exactly
/// this layout.
struct HangingIndentText: UIViewRepresentable {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let color: Color
    let indent: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = indent
        paragraphStyle.firstLineHeadIndent = 0

        let font = UIFont(name: fontName, size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor(color),
            .paragraphStyle: paragraphStyle,
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingCompressedSize.width
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
