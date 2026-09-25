import SwiftUI
import UIKit

/// Shared setup for every text view showing `OfficeTypesetter` output: read-only, black,
/// no insets of its own, and links drawn in their own attributes (the date line keeps
/// its rubric colour, the table-of-contents icon its icon colour).
@MainActor
enum OfficeTextViewStyle {
    static func apply(to textView: UITextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .black
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [:]
        textView.dataDetectorTypes = []
        textView.indicatorStyle = .white
        textView.accessibilityIdentifier = "officeText"
    }
}

/// Link handling shared by both readers: our in-app links run `onLink`, and get no
/// long-press preview menu (they aren't real URLs).
@MainActor
protocol OfficeLinkHandling: AnyObject {
    var linkHandler: (URL) -> Void { get }
}

@MainActor
private func officeAction(for textItem: UITextItem, handler: any OfficeLinkHandling) -> UIAction? {
    guard let url = OfficeLink.url(for: textItem) else { return nil }
    return UIAction { [weak handler] _ in handler?.linkHandler(url) }
}

// MARK: - Vertical: one continuous scroll

/// Vertical reading mode: the whole hour in one scrolling text view. The footer's page
/// count is the scroll position measured in screen heights.
///
/// TextKit 1 (`LayoutReportingTextView.makeTextKit1()`) so the layout manager is available
/// for jumping to a section and for keeping the reading position when the text size changes.
struct VerticalOfficeReader: UIViewRepresentable {
    let office: TypesetOffice
    /// Changes whenever the typeset text does (date, priest, rubrics, text size).
    let officeID: String
    /// Changes only when the date does: a new day starts at the top, a new text size keeps
    /// the reading position.
    let dateKey: String
    let margin: CGFloat
    @Binding var jumpTarget: Int?
    let onLink: (URL) -> Void
    let onPageChange: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> LayoutReportingTextView {
        let textView = LayoutReportingTextView.makeTextKit1()
        OfficeTextViewStyle.apply(to: textView)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.delegate = context.coordinator
        // The page count needs the view's real size and content height, which are only
        // known after its own layout pass (reporting from `updateUIView` gave "Page 1 of 1").
        textView.onLayout = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.reportPage(of: textView)
        }
        return textView
    }

    func updateUIView(_ textView: LayoutReportingTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        textView.textContainerInset = UIEdgeInsets(top: 8, left: margin, bottom: 32, right: margin)

        if coordinator.officeID != officeID {
            let keepPosition = coordinator.dateKey == dateKey && coordinator.officeID != nil
            let anchor = keepPosition ? coordinator.topCharacter(in: textView) : 0
            coordinator.officeID = officeID
            coordinator.dateKey = dateKey
            textView.attributedText = office.text
            textView.layoutIfNeeded()
            coordinator.scroll(textView, toCharacter: anchor)
            coordinator.reportPage(of: textView)
        }
        if let target = jumpTarget {
            textView.layoutIfNeeded()
            coordinator.scroll(textView, toCharacter: target)
            coordinator.clearJumpTarget()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, OfficeLinkHandling {
        var parent: VerticalOfficeReader
        var officeID: String?
        var dateKey: String?
        private var lastReported: (Int, Int)?

        init(parent: VerticalOfficeReader) {
            self.parent = parent
        }

        var linkHandler: (URL) -> Void { parent.onLink }

        func topCharacter(in textView: UITextView) -> Int {
            guard textView.textStorage.length > 0 else { return 0 }
            let point = CGPoint(x: 1, y: max(0, textView.contentOffset.y - textView.textContainerInset.top) + 1)
            let glyph = textView.layoutManager.glyphIndex(for: point, in: textView.textContainer)
            return textView.layoutManager.characterIndexForGlyph(at: glyph)
        }

        func scroll(_ textView: UITextView, toCharacter index: Int) {
            let length = textView.textStorage.length
            guard length > 0 else { return }
            let layoutManager = textView.layoutManager
            layoutManager.ensureLayout(for: textView.textContainer)
            let glyph = layoutManager.glyphIndexForCharacter(at: min(max(0, index), length - 1))
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let maxOffset = max(0, textView.contentSize.height - textView.bounds.height)
            let y = index == 0 ? 0 : min(max(0, lineRect.minY), maxOffset)
            textView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        func clearJumpTarget() {
            Task { @MainActor [weak self] in self?.parent.jumpTarget = nil }
        }

        func reportPage(of scrollView: UIScrollView) {
            let height = scrollView.bounds.height
            guard height > 0 else { return }
            let total = max(1, Int((scrollView.contentSize.height / height).rounded(.up)))
            let current = min(total, max(1, Int((scrollView.contentOffset.y / height).rounded()) + 1))
            if let lastReported, lastReported == (current, total) { return }
            lastReported = (current, total)
            // Deferred: this can run inside a SwiftUI update, where changing state is not allowed.
            Task { @MainActor [weak self] in self?.parent.onPageChange(current, total) }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportPage(of: scrollView)
        }

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            officeAction(for: textItem, handler: self) ?? defaultAction
        }

        func textView(
            _ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            OfficeLink.url(for: textItem) == nil ? UITextItem.MenuConfiguration(menu: defaultMenu) : nil
        }
    }
}

/// A text view that tells its owner whenever it has been laid out.
final class LayoutReportingTextView: UITextView {
    var onLayout: (() -> Void)?
    /// A text view does not retain the storage of a TextKit stack built by hand.
    private var ownedStorage: NSTextStorage?

    /// A TextKit 1 text view (so `layoutManager` is available), built from its parts with
    /// the designated initialiser.
    static func makeTextKit1() -> LayoutReportingTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        let textView = LayoutReportingTextView(frame: .zero, textContainer: container)
        textView.ownedStorage = storage
        return textView
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

// MARK: - Horizontal: book pages

/// Horizontal reading mode: the hour flows through page-sized TextKit containers, one
/// line after another, exactly like a printed book -- a paragraph that doesn't fit
/// continues at the top of the next page, at any text size or orientation. Turned by a
/// sideways slide or, if chosen in Settings, a page curl (`UIPageViewController`'s
/// transition style can't change after creation, so `VespersView` recreates this view
/// when that setting changes).
struct PagedOfficeReader: UIViewControllerRepresentable {
    let office: TypesetOffice
    let officeID: String
    let dateKey: String
    /// The whole area available for a page, between the navigation header and the footer.
    let pageSize: CGSize
    let margin: CGFloat
    let curl: Bool
    @Binding var jumpTarget: Int?
    let onLink: (URL) -> Void
    let onPageChange: (Int, Int) -> Void

    func makeCoordinator() -> OfficePager { OfficePager(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller: UIPageViewController
        if curl {
            controller = UIPageViewController(
                transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
            )
            controller.isDoubleSided = false
        } else {
            controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        }
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(controller)
    }
}

/// Owns the TextKit chain behind `PagedOfficeReader`: one text storage and layout
/// manager, and one text container per page, added until the whole hour is laid out.
@MainActor
final class OfficePager: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UITextViewDelegate,
    OfficeLinkHandling
{
    static let pageTopInset: CGFloat = 8
    static let pageBottomInset: CGFloat = 8

    var parent: PagedOfficeReader
    private var layoutKey = ""
    private var dateKey = ""
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private var containers: [NSTextContainer] = []
    /// One controller per page, reused: a text container can back only one text view.
    private var pages: [Int: OfficePageController] = [:]
    private var currentIndex = 0

    init(parent: PagedOfficeReader) {
        self.parent = parent
        super.init()
        textStorage.addLayoutManager(layoutManager)
    }

    var linkHandler: (URL) -> Void { parent.onLink }

    func update(_ controller: UIPageViewController) {
        let size = parent.pageSize
        let key = "\(parent.officeID)|\(Int(size.width))x\(Int(size.height))|\(parent.margin)"
        if key != layoutKey, size.width > 1, size.height > 1 {
            let keepPosition = parent.dateKey == dateKey && !containers.isEmpty
            let anchor = keepPosition ? firstCharacter(ofPage: currentIndex) : 0
            layoutKey = key
            dateKey = parent.dateKey
            paginate()
            show(page: keepPosition ? page(containingCharacter: anchor) : 0, in: controller)
        }
        if let target = parent.jumpTarget, !containers.isEmpty {
            show(page: page(containingCharacter: headingCharacter(afterSeparatorAt: target)), in: controller)
            Task { @MainActor [weak self] in self?.parent.jumpTarget = nil }
        }
    }

    private var pageTextSize: CGSize {
        CGSize(
            width: max(1, parent.pageSize.width - 2 * parent.margin),
            height: max(1, parent.pageSize.height - Self.pageTopInset - Self.pageBottomInset)
        )
    }

    private func paginate() {
        pages.removeAll()
        while !layoutManager.textContainers.isEmpty {
            layoutManager.removeTextContainer(at: 0)
        }
        containers.removeAll()
        textStorage.setAttributedString(parent.office.text)

        let size = pageTextSize
        // Add pages until the last glyph is laid out. The empty-page check stops a runaway
        // if a single line were ever taller than a whole page.
        while containers.count < 1000 {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            var range = layoutManager.glyphRange(for: container)
            if NSMaxRange(range) >= layoutManager.numberOfGlyphs || range.length == 0 { break }
            // A heading or psalm title at the foot of the page moves to the next one,
            // with the text it introduces: the page is shortened to end above it.
            if let top = keepWithNextTop(in: range), top > 0 {
                container.size = CGSize(width: size.width, height: top)
                range = layoutManager.glyphRange(for: container)
            }
        }
    }

    /// The top of the run of `OfficeTypesetter.keepWithNext` lines that ends the page's
    /// `glyphs`, if it does end with one (and it isn't the whole page).
    private func keepWithNextTop(in glyphs: NSRange) -> CGFloat? {
        var glyph = NSMaxRange(glyphs) - 1
        var top: CGFloat?
        while glyph > glyphs.location {
            let character = layoutManager.characterIndexForGlyph(at: glyph)
            guard textStorage.attribute(OfficeTypesetter.keepWithNext, at: character, effectiveRange: nil) != nil else { break }
            var line = NSRange()
            let rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &line)
            top = rect.minY
            guard line.location > glyphs.location else { return nil }
            glyph = line.location - 1
        }
        return top
    }

    private func firstCharacter(ofPage index: Int) -> Int {
        guard containers.indices.contains(index) else { return 0 }
        let glyphs = layoutManager.glyphRange(for: containers[index])
        return layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil).location
    }

    /// A jump target is a section's separator rule (`TypesetOffice.sectionOffsets`), a
    /// paragraph of its own. The rule can end one page while its heading starts the next,
    /// so jumps go to the page of the paragraph after it: the heading.
    private func headingCharacter(afterSeparatorAt index: Int) -> Int {
        let string = textStorage.string as NSString
        guard index >= 0, index < string.length else { return index }
        let rule = string.paragraphRange(for: NSRange(location: index, length: 0))
        return NSMaxRange(rule) < string.length ? NSMaxRange(rule) : index
    }

    private func page(containingCharacter index: Int) -> Int {
        guard textStorage.length > 0 else { return 0 }
        let glyph = layoutManager.glyphIndexForCharacter(at: min(max(0, index), textStorage.length - 1))
        guard let container = layoutManager.textContainer(forGlyphAt: glyph, effectiveRange: nil) else { return 0 }
        return containers.firstIndex { $0 === container } ?? 0
    }

    private func pageController(_ index: Int) -> OfficePageController? {
        guard containers.indices.contains(index) else { return nil }
        if let existing = pages[index] { return existing }
        let page = OfficePageController(
            index: index, container: containers[index], margin: parent.margin, topInset: Self.pageTopInset, textViewDelegate: self
        )
        pages[index] = page
        return page
    }

    private func show(page index: Int, in controller: UIPageViewController) {
        guard let page = pageController(index) else { return }
        let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
        currentIndex = index
        controller.setViewControllers([page], direction: direction, animated: false)
        report()
    }

    /// Adds pages when the last no longer reaches the end of the hour. The text can reflow
    /// after `paginate()` (page 1's header settles once it is on screen), and a fixed page
    /// count then lost the end of the hour (25 September 2026: Compline stopped
    /// mid-collect, on "Page 11 of 11").
    private func extendIfNeeded() {
        guard let last = containers.last else { return }
        var range = layoutManager.glyphRange(for: last)
        let size = pageTextSize
        while NSMaxRange(range) < layoutManager.numberOfGlyphs, containers.count < 1000 {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            range = layoutManager.glyphRange(for: container)
            if range.length == 0 { break }
        }
    }

    private func report() {
        extendIfNeeded()
        let current = currentIndex + 1
        let total = max(1, containers.count)
        Task { @MainActor [weak self] in self?.parent.onPageChange(current, total) }
    }

    // MARK: UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? OfficePageController else { return nil }
        return pageController(page.index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? OfficePageController else { return nil }
        extendIfNeeded()
        return pageController(page.index + 1)
    }

    // MARK: UIPageViewControllerDelegate

    func pageViewController(
        _ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController], transitionCompleted completed: Bool
    ) {
        guard completed, let page = pageViewController.viewControllers?.first as? OfficePageController else { return }
        currentIndex = page.index
        report()
    }

    // MARK: UITextViewDelegate

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        officeAction(for: textItem, handler: self) ?? defaultAction
    }

    func textView(
        _ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu
    ) -> UITextItem.MenuConfiguration? {
        OfficeLink.url(for: textItem) == nil ? UITextItem.MenuConfiguration(menu: defaultMenu) : nil
    }
}

/// One page: a non-scrolling text view bound to that page's text container.
final class OfficePageController: UIViewController {
    let index: Int
    private let textView: UITextView
    private let margin: CGFloat
    private let topInset: CGFloat

    init(index: Int, container: NSTextContainer, margin: CGFloat, topInset: CGFloat, textViewDelegate: any UITextViewDelegate) {
        self.index = index
        self.margin = margin
        self.topInset = topInset
        let size = container.size
        textView = UITextView(frame: CGRect(origin: .zero, size: size), textContainer: container)
        super.init(nibName: nil, bundle: nil)
        OfficeTextViewStyle.apply(to: textView)
        textView.isScrollEnabled = false
        textView.delegate = textViewDelegate
        // The container's size is the page: `paginate()` decided which lines it holds. A
        // text view would otherwise make it track its own size (and resize it when
        // scrolling is off), reflowing the shared layout so that the last page no longer
        // reached the end of the hour (25 September 2026: Compline stopped mid-collect).
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.size = size
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(textView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = textView.textContainer.size
        textView.frame = CGRect(x: margin, y: topInset, width: size.width, height: size.height)
    }
}

// MARK: - Parallel English: rows of one or two columns

/// One column's text laid out at a fixed width in its own TextKit 1 stack, with its line
/// fragments (each with its paragraph spacing, so consecutive lines tile with no gaps).
@MainActor
final class ColumnLayout {
    let layoutManager = NSLayoutManager()
    private let storage: NSTextStorage
    private let container: NSTextContainer
    /// Line rects in row coordinates: laid out, then moved down by `topSpace`, with the
    /// first line's rect grown upward to the row's top to hold it.
    private(set) var lines: [(rect: CGRect, glyphs: NSRange)] = []
    /// The first paragraph's `paragraphSpacingBefore`. TextKit drops it at the top of a
    /// text, and every row is a text of its own, so a section's rule sat right under the
    /// previous row; it is added back here.
    private let topSpace: CGFloat
    /// Our links, kept under their own key: TextKit draws `.link` in the system's blue,
    /// underlined, when it draws glyphs itself (the date line did).
    static let linkKey = NSAttributedString.Key("BreviariumLink")

    /// `hyphenate`: a narrow column breaks long words with a hyphen rather than
    /// letter by letter ("sæculóru / m." at XXL).
    init(text: NSAttributedString, width: CGFloat, hyphenate: Bool = false) {
        let copy = NSMutableAttributedString(attributedString: text)
        let whole = NSRange(location: 0, length: copy.length)
        copy.enumerateAttribute(.link, in: whole) { value, range, _ in
            guard let value else { return }
            copy.removeAttribute(.link, range: range)
            copy.addAttribute(Self.linkKey, value: value, range: range)
        }
        if hyphenate {
            copy.enumerateAttribute(.paragraphStyle, in: whole) { value, range, _ in
                guard let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
                style.hyphenationFactor = 1
                copy.addAttribute(.paragraphStyle, value: style, range: range)
            }
        }
        topSpace = copy.length > 0 ? (copy.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0 : 0
        storage = NSTextStorage(attributedString: copy)
        container = NSTextContainer(size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)
        let all = layoutManager.glyphRange(for: container)
        var found: [(rect: CGRect, glyphs: NSRange)] = []
        layoutManager.enumerateLineFragments(forGlyphRange: all) { rect, _, _, glyphs, _ in
            found.append((rect, glyphs))
        }
        let space = topSpace
        lines = found.enumerated().map { index, line in
            var rect = line.rect.offsetBy(dx: 0, dy: space)
            if index == 0 {
                rect.origin.y -= space
                rect.size.height += space
            }
            return (rect, line.glyphs)
        }
    }

    /// The height of lines `range`, top of the first to the bottom of the last.
    func height(of range: Range<Int>) -> CGFloat {
        guard let first = range.first, let last = range.last else { return 0 }
        return lines[last].rect.maxY - lines[first].rect.minY
    }

    /// How many lines from `start` fit in `height`.
    func linesFitting(from start: Int, in height: CGFloat) -> Int {
        guard start < lines.count else { return 0 }
        let top = lines[start].rect.minY
        var count = 0
        while start + count < lines.count, lines[start + count].rect.maxY - top <= height + 0.5 { count += 1 }
        return count
    }

    func draw(lines range: Range<Int>, at origin: CGPoint) {
        guard let first = range.first, let last = range.last else { return }
        let glyphs = NSUnionRange(lines[first].glyphs, lines[last].glyphs)
        let point = CGPoint(x: origin.x, y: origin.y - lines[first].rect.minY + topSpace)
        layoutManager.drawBackground(forGlyphRange: glyphs, at: point)
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: point)
    }

    /// The in-app link at `point` (relative to where lines `range` were drawn), if any.
    func link(at point: CGPoint, lines range: Range<Int>) -> URL? {
        guard let first = range.first else { return nil }
        let local = CGPoint(x: point.x, y: point.y + lines[first].rect.minY - topSpace)
        let glyph = layoutManager.glyphIndex(for: local, in: container)
        guard glyph < layoutManager.numberOfGlyphs else { return nil }
        let bounds = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard bounds.insetBy(dx: -8, dy: -8).contains(local) else { return nil }
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        if storage.attribute(.attachment, at: character, effectiveRange: nil) is TableOfContentsAttachment {
            return OfficeLink.tableOfContents
        }
        if let url = storage.attribute(Self.linkKey, at: character, effectiveRange: nil) as? URL, url.scheme == OfficeLink.scheme {
            return url
        }
        return nil
    }

    var plainText: String { storage.string }
}

/// A run of one column's lines placed on a page.
@MainActor
struct ColumnSlice {
    let column: ColumnLayout
    let lines: Range<Int>
    let origin: CGPoint
    var frame: CGRect {
        CGRect(x: origin.x, y: origin.y, width: column.lines.first.map { $0.rect.width } ?? 0, height: column.height(of: lines))
    }
}

/// The parallel office laid out on pages of one size, like `OfficePager`'s book pages: a
/// row that doesn't fit continues at the top of the next page, each column at its own line
/// boundary. A heading or psalm title (`keepWithNext`) never ends a page, a versicle and
/// response (`keepTogether`) never split, and a column never leaves just one line of a
/// longer run at the foot of a page. With an unbounded page height (the vertical reader)
/// everything lands on one page.
@MainActor
struct ParallelLayout {
    let pages: [[ColumnSlice]]
    /// Each row's page and its top on that page, for jumps and for keeping the position.
    let rowPositions: [(page: Int, y: CGFloat)]

    init(office: ParallelOffice, width: CGFloat, pageHeight: CGFloat, gutter: CGFloat) {
        let columnWidth = max(1, (width - gutter) / 2)
        let rows: [[(ColumnLayout, CGFloat)]] = office.rows.map { row in
            switch row {
            case .full(let text, _):
                return [(ColumnLayout(text: text, width: width), 0)]
            case .pair(let latin, let english, _):
                return [
                    (ColumnLayout(text: latin, width: columnWidth, hyphenate: true), 0),
                    (ColumnLayout(text: english, width: columnWidth, hyphenate: true), columnWidth + gutter),
                ]
            }
        }
        var pages: [[ColumnSlice]] = []
        var rowPositions: [(page: Int, y: CGFloat)] = []
        var page: [ColumnSlice] = []
        var y: CGFloat = 0
        func newPage() {
            pages.append(page)
            page = []
            y = 0
        }

        for (index, columns) in rows.enumerated() {
            let keepWithNext: Bool
            let keepTogether: Bool
            switch office.rows[index] {
            case .full(_, let keep): (keepWithNext, keepTogether) = (keep, false)
            case .pair(_, _, let keep): (keepWithNext, keepTogether) = (false, keep)
            }
            var starts = columns.map { _ in 0 }
            var positioned = false
            while zip(columns, starts).contains(where: { column, start in column.0.lines.count > start }) {
                let remaining = zip(columns, starts).map { column, start in column.0.height(of: start..<column.0.lines.count) }
                let rowHeight = remaining.max() ?? 0
                let available = pageHeight - y
                if !positioned {
                    // What must fit with this row's start: all of it (keepTogether), or,
                    // for a heading, the next row's first two lines too.
                    var needed = keepTogether ? rowHeight : min(rowHeight, columns.map { $0.0.height(of: 0..<min(2, $0.0.lines.count)) }.max() ?? 0)
                    if keepWithNext, index + 1 < rows.count {
                        needed = rowHeight + (rows[index + 1].map { $0.0.height(of: 0..<min(2, $0.0.lines.count)) }.max() ?? 0)
                    }
                    if y > 0, needed > available, needed <= pageHeight {
                        newPage()
                        continue
                    }
                    rowPositions.append((page: pages.count, y: y))
                    positioned = true
                }
                if rowHeight <= available {
                    for (column, start) in zip(columns, starts) where start < column.0.lines.count {
                        page.append(ColumnSlice(column: column.0, lines: start..<column.0.lines.count, origin: CGPoint(x: column.1, y: y)))
                    }
                    y += rowHeight
                    break
                }
                // Split: each column takes the lines that fit, but never a single line of
                // a longer run (it moves on with the rest).
                var placedAny = false
                for (offset, column) in columns.enumerated() where starts[offset] < column.0.lines.count {
                    var count = column.0.linesFitting(from: starts[offset], in: available)
                    let left = column.0.lines.count - starts[offset]
                    if count == 1, left > 1, y > 0 { count = 0 }
                    if count == 0, y == 0 { count = 1 }    // a line taller than a page
                    guard count > 0 else { continue }
                    page.append(ColumnSlice(column: column.0, lines: starts[offset]..<starts[offset] + count, origin: CGPoint(x: column.1, y: y)))
                    starts[offset] += count
                    placedAny = true
                }
                newPage()
                if !placedAny, starts.allSatisfy({ $0 == 0 }) {
                    // Nothing of the row fitted after all: it starts on the new page.
                    rowPositions[rowPositions.count - 1] = (page: pages.count, y: 0)
                }
            }
            if !positioned { rowPositions.append((page: pages.count, y: y)) }
        }
        if !page.isEmpty || pages.isEmpty { pages.append(page) }
        self.pages = pages
        self.rowPositions = rowPositions
    }

    var totalHeight: CGFloat {
        (pages.last ?? []).map(\.frame.maxY).max() ?? 0
    }

    func page(ofRow row: Int) -> Int {
        rowPositions.indices.contains(row) ? rowPositions[row].page : 0
    }

    /// The first row that starts on `page`, or, if none does, the row continuing onto it:
    /// the reading position to keep when the layout changes. (It was the *last* row on the
    /// page, so turning the phone moved the reader a page or two on, B1-M5.)
    func firstRow(onPage page: Int) -> Int {
        rowPositions.firstIndex { $0.page == page } ?? rowPositions.lastIndex { $0.page < page } ?? 0
    }
}

/// Draws one page's slices, and turns taps on the page-1 links into `onLink`.
final class ParallelPageView: UIView {
    var slices: [ColumnSlice] = [] {
        didSet {
            setNeedsDisplay()
            accessibilityLabel = slices.map { slice in
                slice.lines.map { index -> String in
                    let glyphs = slice.column.lines[index].glyphs
                    let characters = slice.column.layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                    return (slice.column.plainText as NSString).substring(with: characters)
                }.joined()
            }.joined(separator: "\n")
        }
    }
    var onLink: ((URL) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityIdentifier = "officeText"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        UIColor.black.setFill()
        UIRectFill(rect)
        for slice in slices where slice.frame.insetBy(dx: 0, dy: -4).intersects(rect) {
            slice.column.draw(lines: slice.lines, at: slice.origin)
        }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        for slice in slices where slice.frame.insetBy(dx: -8, dy: -8).contains(point) {
            let local = CGPoint(x: point.x - slice.origin.x, y: point.y - slice.origin.y)
            if let url = slice.column.link(at: local, lines: slice.lines) {
                onLink?(url)
                return
            }
        }
    }
}

/// The parallel office in book pages: `PagedOfficeReader`'s counterpart for English on.
struct ParallelPagedReader: UIViewControllerRepresentable {
    let office: ParallelOffice
    let officeID: String
    let dateKey: String
    let pageSize: CGSize
    let margin: CGFloat
    let gutter: CGFloat
    let curl: Bool
    /// A row index (`ParallelOffice.sectionOffsets`).
    @Binding var jumpTarget: Int?
    let onLink: (URL) -> Void
    let onPageChange: (Int, Int) -> Void

    func makeCoordinator() -> ParallelPager { ParallelPager(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller: UIPageViewController
        if curl {
            controller = UIPageViewController(
                transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
            )
            controller.isDoubleSided = false
        } else {
            controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        }
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(controller)
    }
}

@MainActor
final class ParallelPager: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    var parent: ParallelPagedReader
    private var layoutKey = ""
    private var dateKey = ""
    private var layout: ParallelLayout?
    private var pages: [Int: ParallelPageController] = [:]
    private var currentIndex = 0

    init(parent: ParallelPagedReader) {
        self.parent = parent
    }

    func update(_ controller: UIPageViewController) {
        let size = parent.pageSize
        let key = "\(parent.officeID)|\(Int(size.width))x\(Int(size.height))|\(parent.margin)"
        if key != layoutKey, size.width > 1, size.height > 1 {
            let anchorRow = parent.dateKey == dateKey ? layout?.firstRow(onPage: currentIndex) : nil
            layoutKey = key
            dateKey = parent.dateKey
            pages.removeAll()
            let newLayout = ParallelLayout(
                office: parent.office, width: max(1, size.width - 2 * parent.margin),
                pageHeight: max(1, size.height - OfficePager.pageTopInset - OfficePager.pageBottomInset), gutter: parent.gutter
            )
            layout = newLayout
            show(page: anchorRow.map(newLayout.page(ofRow:)) ?? 0, in: controller)
        }
        if let target = parent.jumpTarget, let layout {
            show(page: layout.page(ofRow: target), in: controller)
            Task { @MainActor [weak self] in self?.parent.jumpTarget = nil }
        }
    }

    private func pageController(_ index: Int) -> ParallelPageController? {
        guard let layout, layout.pages.indices.contains(index) else { return nil }
        if let existing = pages[index] { return existing }
        let page = ParallelPageController(index: index, slices: layout.pages[index], margin: parent.margin) { [weak self] url in
            self?.parent.onLink(url)
        }
        pages[index] = page
        return page
    }

    private func show(page index: Int, in controller: UIPageViewController) {
        guard let page = pageController(index) else { return }
        let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
        currentIndex = index
        controller.setViewControllers([page], direction: direction, animated: false)
        report()
    }

    /// Adds pages when the last no longer reaches the end of the hour. The text can reflow
    /// after `paginate()` (page 1's header settles once it is on screen), and a fixed page
    /// count then lost the end of the hour (25 September 2026: Compline stopped
    /// mid-collect, on "Page 11 of 11").
    private func extendIfNeeded() {
        guard let last = containers.last else { return }
        var range = layoutManager.glyphRange(for: last)
        let size = pageTextSize
        while NSMaxRange(range) < layoutManager.numberOfGlyphs, containers.count < 1000 {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            range = layoutManager.glyphRange(for: container)
            if range.length == 0 { break }
        }
    }

    private func report() {
        extendIfNeeded()
        let current = currentIndex + 1
        let total = max(1, layout?.pages.count ?? 1)
        Task { @MainActor [weak self] in self?.parent.onPageChange(current, total) }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? ParallelPageController else { return nil }
        return pageController(page.index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? ParallelPageController else { return nil }
        return pageController(page.index + 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController], transitionCompleted completed: Bool
    ) {
        guard completed, let page = pageViewController.viewControllers?.first as? ParallelPageController else { return }
        currentIndex = page.index
        report()
    }
}

final class ParallelPageController: UIViewController {
    let index: Int
    private let pageView = ParallelPageView(frame: .zero)
    private let margin: CGFloat

    init(index: Int, slices: [ColumnSlice], margin: CGFloat, onLink: @escaping (URL) -> Void) {
        self.index = index
        self.margin = margin
        super.init(nibName: nil, bundle: nil)
        pageView.slices = slices
        pageView.onLink = onLink
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(pageView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageView.frame = CGRect(
            x: margin, y: OfficePager.pageTopInset,
            width: max(1, view.bounds.width - 2 * margin),
            height: max(1, view.bounds.height - OfficePager.pageTopInset - OfficePager.pageBottomInset)
        )
    }
}

/// The parallel office in one continuous scroll: `VerticalOfficeReader`'s counterpart.
struct ParallelVerticalReader: UIViewRepresentable {
    let office: ParallelOffice
    let officeID: String
    let dateKey: String
    let width: CGFloat
    let margin: CGFloat
    let gutter: CGFloat
    @Binding var jumpTarget: Int?
    let onLink: (URL) -> Void
    let onPageChange: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> LayoutReportingScrollView {
        let scrollView = LayoutReportingScrollView()
        // The page count and a pending jump need the view's real height, known only
        // after its own layout pass ("Page 1 of 1" when reported from `updateUIView`).
        scrollView.onLayout = { [weak coordinator = context.coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.didLayout(scrollView)
        }
        scrollView.backgroundColor = .black
        scrollView.indicatorStyle = .white
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = context.coordinator
        scrollView.addSubview(context.coordinator.pageView)
        return scrollView
    }

    func updateUIView(_ scrollView: LayoutReportingScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let key = "\(officeID)|\(Int(width))|\(margin)"
        if key != coordinator.layoutKey, width > 1 {
            let anchorRow = coordinator.dateKey == dateKey ? coordinator.topRow(in: scrollView) : nil
            coordinator.layoutKey = key
            coordinator.dateKey = dateKey
            let layout = ParallelLayout(office: office, width: max(1, width - 2 * margin), pageHeight: .greatestFiniteMagnitude, gutter: gutter)
            coordinator.layout = layout
            coordinator.pageView.slices = layout.pages.first ?? []
            coordinator.pageView.onLink = { [weak coordinator] url in coordinator?.parent.onLink(url) }
            coordinator.pageView.frame = CGRect(x: margin, y: 8, width: max(1, width - 2 * margin), height: max(1, layout.totalHeight))
            scrollView.contentSize = CGSize(width: width, height: layout.totalHeight + 8 + 32)
            coordinator.pendingRow = anchorRow ?? 0
        }
        if let target = jumpTarget {
            coordinator.pendingRow = target
            Task { @MainActor in coordinator.parent.jumpTarget = nil }
        }
        scrollView.setNeedsLayout()
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ParallelVerticalReader
        var layoutKey = ""
        var dateKey = ""
        var layout: ParallelLayout?
        let pageView = ParallelPageView(frame: .zero)
        /// A row to scroll to once the view has its size.
        var pendingRow: Int?
        private var lastReported: (Int, Int)?

        func didLayout(_ scrollView: UIScrollView) {
            guard scrollView.bounds.height > 0 else { return }
            if let row = pendingRow {
                pendingRow = nil
                scroll(scrollView, toRow: row)
            }
            reportPage(of: scrollView)
        }

        init(parent: ParallelVerticalReader) {
            self.parent = parent
        }

        func topRow(in scrollView: UIScrollView) -> Int? {
            guard let layout else { return nil }
            let top = scrollView.contentOffset.y - 8
            return layout.rowPositions.lastIndex { $0.y <= top + 1 }
        }

        func scroll(_ scrollView: UIScrollView, toRow row: Int) {
            guard let layout, layout.rowPositions.indices.contains(row) else { return }
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let y = row == 0 ? 0 : min(max(0, layout.rowPositions[row].y + 8), maxOffset)
            scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            reportPage(of: scrollView)
        }

        func reportPage(of scrollView: UIScrollView) {
            let height = scrollView.bounds.height
            guard height > 0 else { return }
            let total = max(1, Int((scrollView.contentSize.height / height).rounded(.up)))
            let current = min(total, max(1, Int((scrollView.contentOffset.y / height).rounded()) + 1))
            if let lastReported, lastReported == (current, total) { return }
            lastReported = (current, total)
            Task { @MainActor [weak self] in self?.parent.onPageChange(current, total) }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportPage(of: scrollView)
        }
    }
}

/// A scroll view that tells its owner whenever it has been laid out.
final class LayoutReportingScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
