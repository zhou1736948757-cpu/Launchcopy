import AppCatalogCore
import AppIconPipeline
import AppKit
import LauncherLocalization
import PagingUI
import XCTest
@testable import AppGridUI

/// Native controls remain unshown. Main executes this suite through the serial gate.
@MainActor
final class GridLanguageConsumersTests: XCTestCase {
    private struct UnusedIconLoader: IconLoading {
        enum Failure: Error { case synthetic }
        func load(key: IconKey) async throws -> NSImage { throw Failure.synthetic }
    }

    private func drainText() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func token(_ identity: AnyHashable, generation: UInt64 = 4) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 7, pageIdentity: .init(revision: 7, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: generation,
                         iconKey: nil, surfaceGeneration: 9)
    }

    private func folderContent(_ id: FolderID, page: Int = 0, title: String = "Personal 📁 日本語") -> PagingPageContent {
        .init(presentationID: .init(revision: 7, pageIndex: page),
              items: [.init(slot: 0, identity: AnyHashable(id), title: title)], isPlaceholder: false)
    }

    func testFolderCountAndHelpTranslateAcrossAllLanguagesWithoutRebinding() async {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 120, height: 100))
        let binding = token(AnyHashable(FolderID()))
        cell.bindFolder(title: "用户の名前 📁", memberCount: 1, token: binding)
        cell.setFocused(true)
        cell.layout()
        let frame = cell.frame
        let nameFrame = cell.nameLabel.frame
        var clicks = 0
        cell.onFolderClick = { _ in clicks += 1 }
        let cases: [(InterfaceLanguage, String, String)] = [
            (.english, "1 item", "Folder containing 1 item"),
            (.simplifiedChinese, "1 个项目", "文件夹，含 1 项"),
            (.japanese, "1 項目", "1 項目を含むフォルダ")
        ]
        for (language, count, help) in cases {
            let before = cell.languageFormattingCount
            cell.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(cell.languageFormattingCount, before, "Relabel only stages text")
            await drainText()
            XCTAssertEqual(cell.languageFormattingCount - before, 2)
            XCTAssertEqual(cell.memberCountText, count)
            XCTAssertEqual(cell.accessibilityHelp(), help)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertEqual(cell.boundName, "用户の名前 📁")
            XCTAssertEqual(cell.accessibilityLabel(), "用户の名前 📁")
            XCTAssertEqual(cell.nameLabel.toolTip, "用户の名前 📁")
            XCTAssertTrue(cell.isFocused)
            XCTAssertEqual(cell.frame, frame)
            XCTAssertEqual(cell.nameLabel.frame, nameFrame)
        }
        XCTAssertEqual(clicks, 0)
    }

    func testCountZeroOneManyAndHiddenCaptionRemainSemantic() async {
        let cell = AppGridCellView()
        cell.relabel(strings: LocalizedStrings(language: .english))
        for count in [0, 1, 23] {
            let before = cell.languageFormattingCount
            cell.bindFolder(title: "Group", memberCount: count, token: token(AnyHashable(FolderID())))
            cell.showsAppLabels = false
            XCTAssertEqual(cell.languageFormattingCount, before)
            await drainText()
            XCTAssertEqual(cell.memberCountText, count == 1 ? "1 item" : "\(count) items")
            XCTAssertEqual(cell.accessibilityHelp(), count == 1 ? "Folder containing 1 item" : "Folder containing \(count) items")
            XCTAssertEqual(cell.languageFormattingCount - before, 2)
            XCTAssertTrue(cell.nameLabel.isHidden)
        }
    }

    func testPendingFolderTextCannotWriteIntoReboundApplicationOrClearedCell() async {
        let cell = AppGridCellView()
        cell.relabel(strings: LocalizedStrings(language: .japanese))
        cell.bindFolder(title: "Old", memberCount: 29, token: token(AnyHashable(FolderID())))
        let appToken = token(AnyHashable(AppID.bundleIdentifier("fixture.language.app")))
        cell.bind(name: "Alias 用户 😀", token: appToken)
        let icon = NSImage(size: NSSize(width: 24, height: 24))
        XCTAssertTrue(cell.applyIconIfValid(icon, token: appToken))
        cell.setFocused(true)
        let before = cell.languageFormattingCount
        cell.relabel(strings: LocalizedStrings(language: .english))
        cell.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        await drainText()
        XCTAssertEqual(cell.languageFormattingCount, before)
        XCTAssertEqual(cell.memberCountText, "")
        XCTAssertNil(cell.accessibilityHelp())
        XCTAssertEqual(cell.boundName, "Alias 用户 😀")
        XCTAssertEqual(cell.bindingToken, appToken)
        XCTAssertTrue(cell.iconView.image === icon)
        XCTAssertTrue(cell.isFocused)
        cell.bindFolder(title: "Later", memberCount: 2, token: token(AnyHashable(FolderID())))
        cell.clearContent()
        await drainText()
        XCTAssertEqual(cell.languageFormattingCount, before)
        XCTAssertNil(cell.bindingToken)
        XCTAssertEqual(cell.memberCountText, "")
    }

    func testActualRetainedPageRelabelPreservesTokensFocusIconsAndLayout() async throws {
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        let id = FolderID()
        page.folderSnapshotProvider = { .init(generation: .zero, entries: [.init(id: id, title: "Group", members: [])]) }
        page.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        page.relabel(strings: LocalizedStrings(language: .english))
        page.render(pageIndex: 0, content: folderContent(id), pageCount: 9, reuseGeneration: 3)
        await drainText()
        page.layout()
        let cell = try XCTUnwrap(page.cell(at: 0))
        cell.setFocused(true)
        let binding = cell.bindingToken
        let generation = page.surfaceGeneration
        let stats = pipeline.stats
        let frame = cell.frame
        let appearance = page.itemAppearance
        page.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        page.relabel(strings: LocalizedStrings(language: .japanese))
        await drainText()
        XCTAssertEqual(page.pageLabelText, "9 ページ中 1 ページ目")
        XCTAssertEqual(page.accessibilityLabel(), "9 ページ中 1 ページ目")
        XCTAssertEqual(cell.memberCountText, "0 項目")
        XCTAssertEqual(cell.accessibilityHelp(), "0 項目を含むフォルダ")
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertTrue(cell.isFocused)
        XCTAssertEqual(cell.boundName, "Personal 📁 日本語")
        XCTAssertEqual(cell.frame, frame)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(page.reuseGeneration, 3)
        XCTAssertEqual(page.itemAppearance, appearance)
        XCTAssertEqual(pipeline.stats, stats)
    }

    func testActualPageReuseIsLatestWinsAndFormattingIsDeferredForPageAndCell() async throws {
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        let id = FolderID()
        let english = LocalizedStrings(language: .english)
        let japanese = LocalizedStrings(language: .japanese)
        page.relabel(strings: english)
        page.render(pageIndex: 0, content: folderContent(id), pageCount: 12, reuseGeneration: 0)
        let cell = try XCTUnwrap(page.cell(at: 0))
        XCTAssertEqual(page.languageFormattingCount + cell.languageFormattingCount, 0)
        page.clearForReuse()
        page.relabel(strings: japanese)
        page.render(pageIndex: 10, content: folderContent(id, page: 10, title: "New user title"),
                    pageCount: 12, reuseGeneration: 1)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertEqual(page.languageFormattingCount + cell.languageFormattingCount, 0)
        await drainText()
        XCTAssertEqual(page.languageFormattingCount, 1)
        XCTAssertEqual(cell.languageFormattingCount, 2)
        XCTAssertEqual(page.pageLabelText, "12 ページ中 11 ページ目")
        XCTAssertEqual(cell.boundName, "New user title")
        XCTAssertEqual(cell.accessibilityHelp(), "0 項目を含むフォルダ")
        XCTAssertEqual(cell.bindingToken?.reuseGeneration, 1)
    }

    func testPageTeardownCancelsPendingFormattingIncludingExternallyRetainedCell() async throws {
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        page.relabel(strings: LocalizedStrings(language: .japanese))
        page.render(pageIndex: 0, content: folderContent(FolderID()), pageCount: 3, reuseGeneration: 0)
        let cell = try XCTUnwrap(page.cell(at: 0))
        page.teardown()
        page.relabel(strings: LocalizedStrings(language: .english))
        await drainText()
        XCTAssertEqual(page.languageFormattingCount, 0)
        XCTAssertEqual(cell.languageFormattingCount, 0)
        XCTAssertEqual(page.pageLabelText, "")
        XCTAssertEqual(page.cellCount, 0)
    }

    func testProviderSnapshotInjectionPreservesPendingAndCommittedSearchData() {
        let record = AppRecord(id: .bundleIdentifier("fixture.language.alpha"), displayName: "Alias 日本語",
                               bundleIdentifier: "fixture.language.alpha",
                               canonicalURL: URL(fileURLWithPath: "/SyntheticApps/Alpha.app"),
                               iconIdentity: .from(appID: .bundleIdentifier("fixture.language.alpha")),
                               sourceRootPriority: 0)
        let catalog = CatalogSnapshot(revision: CatalogRevision(7), records: [record])
        let provider = AppGridUIPageContentProvider(snapshot: catalog)
        let query = AppSearchQuery(raw: " Alias 日本語 ", locale: Locale(identifier: "en_US_POSIX"))
        let result = AppSearchResultSet(baseCatalogRevision: catalog.revision,
                                       queryGeneration: .init(4), records: [record])
        provider.stageSearchResult(result)
        XCTAssertTrue(provider.commitPendingSearchResult(query: query))
        provider.stageSearchResult(result)
        provider.receive(CatalogSnapshot(revision: .init(8), records: [record]))
        let content = provider.content(for: .init(revision: 7, pageIndex: 0), itemsPerPage: 35)
        let canonicalGeneration = provider.canonicalPresentationGeneration
        for language in InterfaceLanguage.allCases {
            provider.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(provider.displayedStrings?.language, language)
            XCTAssertEqual(provider.activeQuery, query)
            XCTAssertEqual(provider.pendingSearchResult, result)
            XCTAssertEqual(provider.pendingRevision, 8)
            XCTAssertEqual(provider.servedSnapshot, catalog)
            XCTAssertEqual(provider.canonicalPresentationGeneration, canonicalGeneration)
            XCTAssertEqual(provider.content(for: .init(revision: 7, pageIndex: 0), itemsPerPage: 35), content)
        }
    }

    func testOverlayRelabelKeepsMountedEditorMembersAndCallbacksAndFreezesExit() async throws {
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        let entry = FolderEntry(id: FolderID(), title: "用户 📁 日本語",
                                members: [.bundleIdentifier("fixture.language.member")])
        overlay.relabel(strings: LocalizedStrings(language: .english))
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member alias" }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.layout()
        let member = try XCTUnwrap(overlay.memberCell(at: 0))
        let token = member.bindingToken
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        let editor = NSTextField(string: "Unsaved 用户 draft")
        var invalidations = 0
        var requests = 0
        overlay.onWillInvalidateTitleEditor = { invalidations += 1 }
        overlay.onRequestTitleEdit = { requests += 1 }
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let editorFrame = editor.frame
        overlay.relabel(strings: LocalizedStrings(language: .japanese))
        await drainText()
        XCTAssertTrue(overlay.titleEditorView === editor)
        XCTAssertEqual(editor.stringValue, "Unsaved 用户 draft")
        XCTAssertEqual(editor.frame, editorFrame)
        XCTAssertEqual(overlay.currentEntry, entry)
        XCTAssertEqual(overlay.titleEditButton.title, entry.title)
        XCTAssertEqual(overlay.titleEditButton.toolTip, "フォルダの名前を変更")
        XCTAssertEqual(overlay.titleEditButton.accessibilityLabel(), "フォルダの名前を変更：" + entry.title)
        XCTAssertEqual(member.bindingToken, token)
        XCTAssertEqual(member.boundName, "Member alias")
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats.requests, stats.requests)
        XCTAssertEqual(invalidations, 0)
        XCTAssertEqual(requests, 0)
        overlay.unmountTitleEditor()
        overlay.setVisualOnly(true)
        let label = overlay.titleEditButton.accessibilityLabel()
        let help = overlay.titleEditButton.toolTip
        overlay.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        await drainText()
        XCTAssertEqual(overlay.titleEditButton.accessibilityLabel(), label)
        XCTAssertEqual(overlay.titleEditButton.toolTip, help)
        XCTAssertEqual(overlay.currentEntry, entry)
        XCTAssertFalse(overlay.titleEditButton.isAccessibilityElement())
        XCTAssertEqual(requests, 0)
    }

    func testOverlayFooterAndNavigationTranslateOnSameInstanceInAllLanguages() {
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        overlay.membersPerPage = 1
        let entry = FolderEntry(id: FolderID(), title: "Group", members: [
            .bundleIdentifier("fixture.language.first"), .bundleIdentifier("fixture.language.second")
        ])
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "App" }
        let cases: [(InterfaceLanguage, String, String, String)] = [
            (.english, "Page 1 of 2", "Previous page", "Next page"),
            (.simplifiedChinese, "第 1 页，共 2 页", "上一页", "下一页"),
            (.japanese, "2 ページ中 1 ページ目", "前のページ", "次のページ")
        ]
        let controls = overlay.titleEditorHostView.subviews.compactMap { $0 as? NSButton }
        let labels = overlay.titleEditorHostView.subviews.compactMap { $0 as? NSTextField }
        for (language, footer, previous, next) in cases {
            overlay.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(labels.contains { $0.stringValue == footer })
            XCTAssertTrue(controls.contains { $0.accessibilityLabel() == previous })
            XCTAssertTrue(controls.contains { $0.accessibilityLabel() == next })
            XCTAssertEqual(overlay.currentEntry, entry)
            XCTAssertEqual(overlay.currentInnerPage, 0)
        }
    }
}
