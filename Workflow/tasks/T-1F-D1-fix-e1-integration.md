# T-1F-D1-fix-e1-integration — Wave 1: drag commit → provider presentation + focus reconcile + LayoutStore persist (Defect 2)

Status: ready
Wave: 1 (run BEFORE T-1F-D1-fix-ui; AppDelegate.swift shared → sequential)
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified)
- AppDelegate.swift:547-549 `coordinator.onCommit = { [weak self] newLayout in self?.sessionLayout = newLayout }` only stages sessionLayout; the committed layout is never applied to the provider/rendering → grid never re-renders → reorder and createFolder have no visible effect (user defect 2).
- AppGridUIPageContentProvider has no API to apply a committed PersistentWorkspaceLayout: presentationEntries is private(set), derived from TopLevelComposition.build(catalog:folders:) (folders first, ungrouped apps in catalog order) — cannot represent layout.topLevelOrder (arbitrary interleaving) or reorder of ungrouped apps.

## 2. Fix spec
### 2a. Sources/AppGridUI/AppGridUIPageContentProvider.swift — new public API
Add:
```swift
@discardableResult
public func applyCommittedLayout(_ layout: PersistentWorkspaceLayout,
                                 atCurrentPage currentPage: Int,
                                 itemsPerPage: Int) -> AppGridPresentationUpdate?
```
Semantics: resolve layout.topLevelOrder entries against servedSnapshot (PersistentAppReference → AppRecord; FolderID → PersistentFolderRecord → FolderEntry with members resolved to AppIDs); skip unresolvable entries; set presentationEntries (in layout order), presentationRecords (app-only projection), servedFolderSnapshot (FolderSnapshot from layout.folders, generation incremented); compute pageCount (ceil(count/itemsPerPage), min 1 for non-empty); clamp currentPage; return AppGridPresentationUpdate (reuse existing anchor/remap helpers where applicable; plan.snapshotRevision = servedSnapshot.revision). No-op (return nil) if servedSnapshot is nil.

### 2b. Sources/PagingPrototypeApp/AppDelegate.swift — wire onCommit
Replace onCommit body (:547-549) with:
1. `sessionLayout = newLayout` (keep layoutProvider consistent).
2. `guard let provider = assembly?.provider, let surface else { return }`; call `provider.applyCommittedLayout(newLayout, atCurrentPage: surface.core.committedPage, itemsPerPage: surface.itemsPerPage)`.
3. If update non-nil → `applyPresentationUpdate(update, overridePageCount: true)` (existing machinery: surface.refreshPresentation(), setPageCount, telemetry, focus layout rebuild via keyboardController?.applyLayout).
4. Async persist: `Task { await layoutStore?.enqueue(newLayout) }` — add `private var layoutStore: LayoutStore?`; create at startup with the existing production implementation (LayoutStoreActor; ApplicationSupportLayoutStoreDirectory "PagingPrototypeLayout"); verify its init signature when wiring. Do NOT block the main thread; enqueue is a coalescing sink.
5. teardownAll: also `layoutStore = nil` (sessionLayout already reset).

## 3. Write scope
- Sources/PagingPrototypeApp/AppDelegate.swift
- Sources/AppGridUI/AppGridUIPageContentProvider.swift
- New test file(s) under Tests/ (provider applyCommittedLayout unit tests; integration test if the existing harness supports it)

## 4. Forbidden writes
- Frozen: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift
- Existing tests: do not modify unless this packet explicitly says so (it does not)
- Docs/, PROVENANCE/; Workflow/results/ only for the Worker result file

## 5. Required reading (minimal, ≤4 files)
1. Sources/PagingPrototypeApp/AppDelegate.swift — installDragUI (:524-576), applyPresentationUpdate (:635-653), applyPendingAtIdleBoundary (:659-675), teardownAll (:906-951)
2. Sources/AppGridUI/AppGridUIPageContentProvider.swift — applyPending (:188-240), remapComposition (:344-373), content(for:) (:284-321)
3. Sources/AppGridUI/LayoutStore/LayoutStore.swift — protocol + ApplicationSupportLayoutStoreDirectory
4. Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift — onCommit seam (:41), makeSessionLayout (:385-406)

## 6. Verification
- swift build -c debug → exit 0
- swift test (full suite): baseline 997 all green + new tests green; out-of-scope failures reported, not fixed
- swift build -c release → exit 0

## 7. Acceptance (user defect 2)
- Drag reorder of two top-level apps: grid re-renders in new order after drop.
- Drag A onto B (createFolder): grid shows a folder cell containing A+B after drop.
- Committed layout is enqueued to LayoutStore (persist path exercised; no crash on enqueue).
- After commit, clicking the moved cells still works (layoutProvider = sessionLayout stays consistent with the visible grid).

## 8. Output discipline
- Write Workflow/results/T-1F-D1-fix-e1-integration.md early with Status: in progress; final: Status, root cause confirmation, changes, verification evidence (build/test exit codes + counts), acceptance mapping, risks.
- Reply <250 words, no large code blocks. Privacy redline: neutral counters only.
