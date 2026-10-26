import AppCatalogCore
import AppIconPipeline
import AppKit
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI
@testable import PagingPrototypeApp

/// Actual AppKit consumers without showing windows; execution belongs to Main.
@MainActor
final class PagerLanguageConsumersTests: XCTestCase {
    private func drainText() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func makeSurface(count: Int = 100, lab: Bool = false) -> PagingSurface {
        let surface = PagingSurface(pageCount: count, labMode: lab)
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()
        return surface
    }

    private func emptyContent(page: Int) -> PagingPageContent {
        .init(presentationID: .init(revision: 1, pageIndex: page), items: [], isPlaceholder: true)
    }

    func testHostRenderRelabelAndActualReuseNeverFormatSynchronously() async {
        let host = PageHostView()
        let english = LocalizedStrings(language: .english)
        let japanese = LocalizedStrings(language: .japanese)
        host.relabel(strings: english)
        host.render(pageIndex: 0, content: emptyContent(page: 0), pageCount: 4, reuseGeneration: 0)
        XCTAssertEqual(host.languageFormattingCount, 0)
        host.clearForReuse()
        host.relabel(strings: japanese)
        host.render(pageIndex: 3, content: emptyContent(page: 3), pageCount: 4,
                    reuseGeneration: host.reuseGeneration)
        XCTAssertEqual(host.languageFormattingCount, 0)
        await drainText()
        XCTAssertEqual(host.languageFormattingCount, 1)
        XCTAssertEqual(host.accessibilityLabel(), "4 ページ中 4 ページ目")
        XCTAssertEqual(host.pageIndex, 3)
        XCTAssertEqual(host.reuseGeneration, 1)
        host.clearForReuse()
        await drainText()
        XCTAssertEqual(host.accessibilityLabel(), "")
        XCTAssertEqual(host.languageFormattingCount, 1)
    }

    func testSurfaceRetainedHostAndEmptyStateUseEverySelectedLanguage() async throws {
        let surface = makeSurface(count: 3)
        defer { surface.teardown() }
        let host = try XCTUnwrap(surface.hostForPage(0))
        let frame = host.frame
        let generation = host.reuseGeneration
        let layouts = surface.layoutPerformedCount
        let cases: [(InterfaceLanguage, String, String)] = [
            (.english, "Page 1 of 3", "No pages"),
            (.simplifiedChinese, "第 1 页，共 3 页", "无页面"),
            (.japanese, "3 ページ中 1 ページ目", "ページなし")
        ]
        for (language, label, _) in cases {
            surface.relabel(strings: LocalizedStrings(language: language))
            await drainText()
            XCTAssertTrue(surface.hostForPage(0) === host)
            XCTAssertEqual(host.accessibilityLabel(), label)
            XCTAssertEqual(surface.accessibilityDescription, label)
            XCTAssertEqual(surface.accessibilityValue() as? String, label)
            XCTAssertEqual(host.frame, frame)
            XCTAssertEqual(host.reuseGeneration, generation)
            XCTAssertEqual(surface.layoutPerformedCount, layouts)
            XCTAssertEqual(surface.core.committedPage, 0)
        }
        surface.core.setPageCount(0)
        surface.relayoutPages()
        for (language, _, noPages) in cases {
            surface.relabel(strings: LocalizedStrings(language: language))
            await drainText()
            XCTAssertEqual(surface.accessibilityValue() as? String, noPages)
            XCTAssertEqual(surface.accessibilityDescription, noPages)
            XCTAssertEqual(surface.liveHostCount, 0)
        }
    }

    func testSurfaceReusesPhysicalHostsAndInjectsNewestSnapshotWithoutRebindOnRelabel() async throws {
        let surface = makeSurface()
        defer { surface.teardown() }
        surface.relabel(strings: LocalizedStrings(language: .english))
        await drainText()
        var initialHosts: [PageHostView] = []
        for index in 0..<100 {
            if let host = surface.hostForPage(index) { initialHosts.append(host) }
        }
        var didReuse = false
        surface.onPagePrepared = { _, reused in didReuse = didReuse || reused }
        XCTAssertTrue(surface.requestPage(99))
        for _ in 0..<600 {
            if !surface.core.isAnimating { break }
            let count = surface.languageFormattingCount + surface.diagnosticFormattingCount
            let hostCounts = initialHosts.map(\.languageFormattingCount)
            surface.advanceFrame(deltaTime: 1.0 / 60)
            XCTAssertEqual(surface.languageFormattingCount + surface.diagnosticFormattingCount, count)
            XCTAssertEqual(initialHosts.map(\.languageFormattingCount), hostCounts)
        }
        XCTAssertEqual(surface.core.committedPage, 99)
        XCTAssertTrue(didReuse)
        let last = try XCTUnwrap(surface.hostForPage(99))
        let generation = last.reuseGeneration
        let layoutCount = surface.layoutPerformedCount
        surface.relabel(strings: LocalizedStrings(language: .japanese))
        await drainText()
        XCTAssertEqual(surface.accessibilityDescription, "100 ページ中 100 ページ目")
        XCTAssertEqual(last.accessibilityLabel(), "100 ページ中 100 ページ目")
        XCTAssertEqual(last.reuseGeneration, generation)
        XCTAssertEqual(surface.layoutPerformedCount, layoutCount)
        XCTAssertLessThanOrEqual(surface.liveHostCount + surface.poolHostCount, 14)
        XCTAssertTrue(initialHosts.contains { $0.reuseGeneration > 0 }, "Checks actual retained host reuse")
    }

    func testSurfaceTeardownCancelsDeferredHostSurfaceAndDiagnosticFormatting() async throws {
        let surface = makeSurface(count: 5, lab: true)
        let host = try XCTUnwrap(surface.hostForPage(0))
        surface.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertTrue(surface.requestPage(4))
        surface.advanceFrame(deltaTime: 1.0 / 60)
        surface.teardown()
        await drainText()
        XCTAssertEqual(surface.languageFormattingCount, 0)
        XCTAssertEqual(surface.diagnosticFormattingCount, 0)
        XCTAssertEqual(host.languageFormattingCount, 0)
        XCTAssertEqual(surface.accessibilityDescription, "")
        surface.relabel(strings: LocalizedStrings(language: .english))
        await drainText()
        XCTAssertEqual(surface.languageFormattingCount, 0)
    }

    func testCountChangeStagesExistingHostCountWithoutRendering() async throws {
        let surface = makeSurface(count: 5)
        defer { surface.teardown() }
        surface.relabel(strings: LocalizedStrings(language: .japanese))
        await drainText()
        let host = try XCTUnwrap(surface.hostForPage(0))
        let generation = host.reuseGeneration
        let formats = host.languageFormattingCount
        surface.core.setPageCount(3)
        surface.relayoutPages()
        XCTAssertEqual(host.languageFormattingCount, formats)
        await drainText()
        XCTAssertEqual(host.accessibilityLabel(), "3 ページ中 1 ページ目")
        XCTAssertEqual(host.reuseGeneration, generation)
        XCTAssertTrue(surface.hostForPage(0) === host)
    }

    func testDotsRelabelPreservesManuallyBrowsedWindowControlsAndCallbacks() async throws {
        _ = NSApplication.shared
        let dots = PageDotsView(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
        defer { dots.teardown() }
        dots.update(pageCount: 30, committedPage: 0, isEnabled: true)
        let buttons = dots.subviews.compactMap { $0 as? NSButton }
        let next = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "launchcopy.chrome.page-window.next" })
        next.performClick(nil)
        dots.layout()
        let ids = buttons.map(ObjectIdentifier.init)
        let tags = buttons.map(\.tag)
        let frames = buttons.map(\.frame)
        let selected = buttons.map(\.state)
        let enabled = buttons.map(\.isEnabled)
        var requests: [Int] = []
        dots.onRequestPage = { requests.append($0) }
        let cases: [(InterfaceLanguage, String, String, String)] = [
            (.english, "Page navigation", "Show next pages", "Page 1 of 30"),
            (.simplifiedChinese, "分页导航", "显示后面的页码", "第 1 页，共 30 页"),
            (.japanese, "ページ移動", "次のページを表示", "30 ページ中 1 ページ目")
        ]
        for (language, navigation, nextLabel, page) in cases {
            let formats = dots.languageFormattingCount
            dots.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(dots.languageFormattingCount, formats)
            await drainText()
            XCTAssertEqual(dots.languageFormattingCount - formats, 10, "Nine dots and one surface value")
            XCTAssertEqual(dots.accessibilityLabel(), navigation)
            XCTAssertEqual(next.accessibilityLabel(), nextLabel)
            XCTAssertEqual(next.toolTip, nextLabel)
            XCTAssertEqual(dots.accessibilityValue() as? String, page)
            XCTAssertEqual(buttons.map(ObjectIdentifier.init), ids)
            XCTAssertEqual(buttons.map(\.tag), tags)
            XCTAssertEqual(buttons.map(\.frame), frames)
            XCTAssertEqual(buttons.map(\.state), selected)
            XCTAssertEqual(buttons.map(\.isEnabled), enabled)
            XCTAssertTrue(requests.isEmpty)
        }
        let first = try XCTUnwrap(buttons.first { !$0.isHidden && $0.tag == 9 })
        first.performClick(nil)
        XCTAssertEqual(requests, [9])
    }

    func testDotCurrentSuffixValuesIntMaxNoPagesAndTeardown() async throws {
        let dots = PageDotsView()
        dots.update(pageCount: Int.max, committedPage: Int.max - 1, isEnabled: false)
        dots.relabel(strings: LocalizedStrings(language: .japanese))
        await drainText()
        let buttons = dots.subviews.compactMap { $0 as? NSButton }
        let selected = try XCTUnwrap(buttons.first { !$0.isHidden && $0.tag == Int.max - 1 })
        XCTAssertEqual(selected.accessibilityLabel(), "\(Int.max) ページ中 \(Int.max) ページ目、現在のページ")
        XCTAssertEqual(selected.accessibilityValue() as? String, "現在のページ")
        XCTAssertTrue(buttons.filter { !$0.isHidden && $0.tag >= 0 && $0 !== selected }.allSatisfy {
            $0.accessibilityValue() as? String == "未選択"
        })
        XCTAssertEqual(buttons.count, 11)
        dots.update(pageCount: 0, committedPage: 0, isEnabled: true)
        dots.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        await drainText()
        XCTAssertEqual(dots.accessibilityValue() as? String, "无页面")
        XCTAssertTrue(dots.isHidden)
        XCTAssertTrue(buttons.allSatisfy(\.isHidden))
        dots.update(pageCount: 3, committedPage: 1, isEnabled: true)
        let count = dots.languageFormattingCount
        dots.teardown()
        dots.relabel(strings: LocalizedStrings(language: .english))
        await drainText()
        XCTAssertEqual(dots.languageFormattingCount, count)
    }

    func testTitleEditorRelabelPreservesActualFieldEditorSelectionResponderAndDraft() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        window.contentView = root
        let editor = FolderTitleEditor()
        editor.frame = NSRect(x: 20, y: 30, width: 300, height: 30)
        editor.stringValue = "Unsaved 用户 😀 draft"
        editor.fallbackTitle = "Existing user title"
        root.addSubview(editor)
        var commits: [String] = []
        var cancels = 0
        editor.onCommit = { commits.append($0) }
        editor.onCancel = { cancels += 1 }
        defer { editor.dismissWithoutCallback(); window.close() }
        XCTAssertTrue(window.makeFirstResponder(editor))
        let fieldEditor = try XCTUnwrap(editor.currentEditor() as? NSTextView)
        fieldEditor.setSelectedRange(NSRange(location: 2, length: 7))
        let selection = fieldEditor.selectedRange()
        let text = fieldEditor.string
        let cases: [(InterfaceLanguage, String)] = [
            (.english, "Folder name"), (.simplifiedChinese, "文件夹名称"), (.japanese, "フォルダ名")
        ]
        for (language, name) in cases {
            editor.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(editor.placeholderString, name)
            XCTAssertEqual(editor.accessibilityLabel(), name)
            XCTAssertTrue(window.firstResponder === fieldEditor)
            XCTAssertTrue(editor.currentEditor() === fieldEditor)
            XCTAssertEqual(fieldEditor.string, text)
            XCTAssertEqual(fieldEditor.selectedRange(), selection)
            XCTAssertEqual(editor.fallbackTitle, "Existing user title")
            XCTAssertTrue(commits.isEmpty)
            XCTAssertEqual(cancels, 0)
        }
        editor.commit()
        XCTAssertEqual(commits, [text])
        editor.commit()
        XCTAssertEqual(commits.count, 1)
    }

    private struct UnusedIconLoader: IconLoading {
        enum Failure: Error { case synthetic }
        func load(key: IconKey) async throws -> NSImage { throw Failure.synthetic }
    }

    private final class FolderContentProvider: PagingPageContentProviding {
        let folders = (0..<100).map { _ in FolderID() }
        var servedRevision: UInt64? { 7 }
        var servedPageCount: Int? { folders.count }
        func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
            .init(presentationID: presentation,
                  items: [.init(slot: presentation.pageIndex,
                                identity: AnyHashable(folders[presentation.pageIndex]), title: "User folder")],
                  isPlaceholder: false)
        }
    }

    func testActualRendererFrameTransitiveFormattingCountIncludesEveryRetainedPageCellHostAndDots() async {
        let strings = LocalizedStrings(language: .japanese)
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        let provider = FolderContentProvider()
        let surface = makeSurface(lab: true)
        let dots = PageDotsView()
        defer { dots.teardown(); surface.teardown(); renderer.teardown(); pipeline.shutdown() }
        renderer.relabel(strings: strings)
        surface.relabel(strings: strings)
        dots.relabel(strings: strings)
        surface.contentProvider = provider
        surface.renderer = renderer
        var hosts: [ObjectIdentifier: PageHostView] = [:]
        var pages: [ObjectIdentifier: AppGridPageView] = [:]
        var cells: [ObjectIdentifier: AppGridCellView] = [:]
        func captureViews() {
            for index in 0..<100 {
                if let host = surface.hostForPage(index) { hosts[ObjectIdentifier(host)] = host }
                if let page = renderer.pageView(forPage: index) {
                    pages[ObjectIdentifier(page)] = page
                    for slot in 0..<page.cellCount {
                        if let cell = page.cell(at: slot) { cells[ObjectIdentifier(cell)] = cell }
                    }
                }
            }
        }
        func formats() -> Int {
            surface.languageFormattingCount + surface.diagnosticFormattingCount + dots.languageFormattingCount
                + hosts.values.reduce(0) { $0 + $1.languageFormattingCount }
                + pages.values.reduce(0) { $0 + $1.languageFormattingCount }
                + cells.values.reduce(0) { $0 + $1.languageFormattingCount }
        }
        captureViews()
        await drainText()
        var reuseEvents = 0
        surface.onPagePrepared = { _, reused in if reused { reuseEvents += 1 } }
        surface.onPageNavigationChange = { [weak surface, weak dots] in
            guard let surface, let dots else { return }
            dots.update(pageCount: surface.core.pageCount, committedPage: surface.core.committedPage, isEnabled: true)
        }
        for target in [99, 0, 87] {
            XCTAssertTrue(surface.requestPage(target))
            for _ in 0..<600 {
                if !surface.core.isAnimating { break }
                captureViews()
                let before = formats()
                surface.advanceFrame(deltaTime: 1.0 / 60)
                captureViews()
                XCTAssertEqual(formats(), before, "Includes newly created/reused and retired consumers")
                XCTAssertLessThanOrEqual(surface.liveHostCount + surface.poolHostCount, 14)
            }
            XCTAssertEqual(surface.core.committedPage, target)
            let beforeDrain = formats()
            await drainText()
            XCTAssertGreaterThan(formats(), beforeDrain, "The queued presentation actually formats after the stack exits")
            XCTAssertEqual(surface.accessibilityDescription, "100 ページ中 \(target + 1) ページ目")
            XCTAssertEqual(surface.hostForPage(target)?.accessibilityLabel(), "100 ページ中 \(target + 1) ページ目")
            XCTAssertEqual(renderer.pageView(forPage: target)?.pageLabelText, "100 ページ中 \(target + 1) ページ目")
            XCTAssertEqual(renderer.pageView(forPage: target)?.cell(at: 0)?.accessibilityHelp(), "0 項目を含むフォルダ")
        }
        XCTAssertGreaterThan(reuseEvents, 0)
        XCTAssertTrue(hosts.values.contains { $0.reuseGeneration > 0 })
        XCTAssertTrue(cells.values.contains { $0.languageFormattingCount > 0 })
        XCTAssertEqual(pipeline.stats.requests, 0, "Folder-only frame coverage never requests app icons")
    }
}
