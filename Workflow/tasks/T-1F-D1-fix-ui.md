# T-1F-D1-fix-ui — Wave 2: preview cell visual + click-not-swallowed + folder-inner member verify/fix (Defects 1/3/4)

Status: ready
Wave: 2 (run AFTER T-1F-D1-fix-e1-integration; AppDelegate.swift shared → sequential)
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified)
- Defect 1: DragUIVisuals.showPreview(title:at:) (:46-64) builds a 140x56 rounded rect + text label only; coordinator .dragBegan passes only sourceCell?.boundName (DragUISessionCoordinator.swift handleEvents .dragBegan).
- Defect 3: DragSessionController.pointerDown (:71) `guard sourcePresent(source, in: layout) else { return events }` swallows clicks: after a createFolder commit, sessionLayout moved A+B into a folder, so clicking top-level A → sourcePresent(.topLevelApp(A), in: sessionLayout) = false → no .pressed → no .clicked → click dead. Matches the user report exactly.
- Defect 4: folder-inner member clicks/drags unresponsive. Static chain: FolderOverlayView.mouseDown (:267-284) → coordinator.pointerDown(sourceCell: memberCell, memberFolderID: currentEntry?.id) → resolveSource (:329-343) → controller.pointerDown → sourcePresent(.folderMember). Member cells DO get bindingToken (memberToken sets appID). Failure point NOT yet confirmed — Worker must verify first (see §2c).

## 2. Fix spec
### 2a. Defect 1 — preview shows source cell visual
- DragUISessionCoordinator.swift handleEvents .dragBegan: replace `visuals.showPreview(title: sourceCell?.boundName, at: ...)` with `visuals.showPreview(sourceCell: sourceCell, at: ...)`.
- DragUIVisuals.swift: add `public func showPreview(sourceCell: AppGridCellView?, at point: NSPoint)`; build a mini cell view: rounded rect (existing styling) + iconView (sourceCell.iconView.image, 48pt) + nameLabel (sourceCell.boundName, 11pt) laid out like AppGridCellView (icon top, label bottom); size ≈ cell proportions (e.g. 96x88 or sourceCell.bounds.size scaled); keep movePreview frame math (point.x - w/2, point.y + 24) and Reduce Motion behavior. Keep old showPreview(title:at:) as a thin wrapper or remove if unused by tests (check tests first; do not break existing tests).
- Privacy: preview content is same-source (cell's own icon/name) — no new exposure.

### 2b. Defect 3 — click must not be swallowed by the stale-source guard
Coordinator-level click fallback (keeps the pure controller and its tests untouched):
- DragUISessionCoordinator.swift: add `private var clickFallbackCell: AppGridCellView?`.
- pointerDown: after `controller.pointerDown(...)`, if no `.pressed` event was produced (stale source) AND sourceCell != nil → `clickFallbackCell = sourceCell` (do NOT arm pendingBlankPress).
- pointerDragged: if clickFallbackCell != nil and distance >= dragStartThresholdPT → `clickFallbackCell = nil` (drag attempt on stale source: no-op).
- pointerUp: if clickFallbackCell != nil → if distance < threshold → `onCellClick(clickFallbackCell)`; clear fallback; return (skip controller path).
- endSession/cancel/teardown: clear clickFallbackCell.
- Wave 1 (layout sync) is the primary mitigation; this fallback is defense in depth.

### 2c. Defect 4 — folder-inner verify FIRST, then fix
Verification-first (mandatory before any fix): confirm the actual failure point with a targeted test or runtime probe:
1. Member cell bindingToken non-nil with appID (overlay memberToken) — expected: yes.
2. currentEntry?.id non-nil while overlay visible — expected: yes.
3. servedFolderSnapshot non-nil and contains the open folder — expected: yes (lab).
4. Drive overlay.mouseDown → coordinator.pointerDown → controller: assert .pressed produced; then mouseUp under threshold → assert .clicked → onCellClick fired → AppDelegate.handleDragCellClick (:612-626) → launchMember path.
5. Check whether the stale-source guard (2b) is the swallowing point after any prior commit (member moved in sessionLayout).
Fix what verification pinpoints, within write scope; if the chain is intact, the defect-3 fix (2b) + Wave-1 layout sync are the fix — document the evidence.

## 3. Write scope
- Sources/AppGridUI/DragUI/DragUIVisuals.swift
- Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
- Sources/AppGridUI/FolderOverlayView.swift (only if verification pinpoints a defect there)
- Sources/PagingPrototypeApp/AppDelegate.swift (only if verification pinpoints handleDragCellClick/launchMember)
- New test file(s) under Tests/

## 4. Forbidden writes
- Frozen: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift
- Existing tests: do not modify unless this packet explicitly says so (it does not)
- Docs/, PROVENANCE/; Workflow/results/ only for the Worker result file

## 5. Required reading (minimal, ≤4 files)
1. Sources/AppGridUI/DragUI/DragUIVisuals.swift — showPreview (:46-64), movePreview (:67-72), configureViews (:191-227)
2. Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift — pointerDown (:98-123), pointerUp (:153-191), handleEvents .dragBegan (:227-267), resolveSource (:329-343), endSession (:311-325)
3. Sources/AppGridUI/DragSession/DragSessionController.swift — pointerDown (:62-92), sourcePresent (:263-272)
4. Sources/AppGridUI/FolderOverlayView.swift — mouseDown (:267-284), hitTest (:297-303), memberToken (:356-367)

## 6. Verification
- swift build -c debug → exit 0
- swift test (full suite): baseline 997 all green + new tests green; out-of-scope failures reported, not fixed
- swift build -c release → exit 0

## 7. Acceptance (user defects 1/3/4)
- Defect 1: during drag, the preview shows the source cell's icon+name block (not bare text).
- Defect 3: after a createFolder/reorder commit, clicking the involved apps launches/opens normally (no swallowed clicks).
- Defect 4: inside a folder, member clicks activate the member (or close the folder on blank) and member drags commit; evidence of the verified failure point recorded in the result file.

## 8. Output discipline
- Write Workflow/results/T-1F-D1-fix-ui.md early with Status: in progress; final: Status, defect-4 verification evidence (which link failed), changes, verification evidence, acceptance mapping, risks.
- Reply <250 words, no large code blocks. Privacy redline: neutral counters only.
