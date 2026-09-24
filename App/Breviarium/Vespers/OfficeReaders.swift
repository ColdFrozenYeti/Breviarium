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
            show(page: page(containingCharacter: target), in: controller)
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
            let range = layoutManager.glyphRange(for: container)
            if NSMaxRange(range) >= layoutManager.numberOfGlyphs || range.length == 0 { break }
        }
    }

    private func firstCharacter(ofPage index: Int) -> Int {
        guard containers.indices.contains(index) else { return 0 }
        let glyphs = layoutManager.glyphRange(for: containers[index])
        return layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil).location
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

    private func report() {
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
        textView = UITextView(frame: CGRect(origin: .zero, size: container.size), textContainer: container)
        super.init(nibName: nil, bundle: nil)
        OfficeTextViewStyle.apply(to: textView)
        textView.isScrollEnabled = false
        textView.delegate = textViewDelegate
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
