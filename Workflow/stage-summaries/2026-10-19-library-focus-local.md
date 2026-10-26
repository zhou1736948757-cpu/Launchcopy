# Library local focus decoration follow-up

## Objective and baseline
User physically reports “宽蓝框仍然残留” on galleryr2/559c133c. Previous close-time cleanup is insufficient. Default cards/layout/physics remain accepted scope and unchanged; no new visual-pass claim. Baseline530inputs/full3236/0 refers to earlier source only.

## Plan and ownership
Main owns local search focus drawing and view integration, serial tests/build/package and CUA. One independent read-only audit examines native field-editor/transform alternatives and then reviews patch. Max3inclMain, no formal workflow overhead. Local in-bounds drawing replaces only Library search native external ring while preserving keyboard visibility and editor semantics; see appended specification. No speculative paging changes or per-frame invalidation.

## Verification gates
Regression tests, independent source review, frozen full/build/package, native visible focus/control checks, then one physical swipe confirmation. No real app actions, formal data, install/sign/commit/reset/signals/reference source/private screenshot files. Causal root of pixels remains unproven.

## Initial implementation and test discriminator
Main added LibrarySearchField.swift and seven mounted/native-editor tests, integrated only AppLibraryView search type and focus-state notifications. First focused run60tests/1assertion failed: NSView.needsDisplay remains dirty for unrelated native field/editor/layer work even after clearing it. Replaced that nondiscriminating assertion with the actual refresh method's discardable redraw-request Bool; unchanged states return before setting needsDisplay, key changes returntrue. No focus or IME assertion removed. Unrelated pre-existing conditional-cast/weak-mutability warnings appeared when test target recompiled; do not claim whole-tree warning-free from cached builds.
Current CUA oldr2 observation: mainfirstpage, inactivewindow, firstresponderwindow, no visibleblue at capture. This cannot negate the user's active/physical report and is not a fixed-case observation; no screenshots saved.

## Final source freeze and review
Independent Mill BOUNDED SOURCE ACCEPT (no blocking finding), including native cell mask clipping, explicit draw-based mode, actual editor-handoff/window observer regression. All agents closed. Focused-r3 before final override exposed a genuine API assumption: NSSearchField inherited wantsUpdateLayer=true, so relying on draw(_:) alone would not guarantee the replacement stroke. Final override explicitly selects draw mode; frozen final rerun must cover it. Final532inputs differ from galleryr2 in only AppLibraryView.swift/newLibrarySearchField.swift/newLibrarySearchFocusDrawingTests.swift;9newtests, no navigator/Core/owner/physics/data change. First dirty-state assertion and inherited-drawmode failure remain in logs; no weakened feature acceptance. Serial final focused/full/Debug/Release/package underway.

## Native prototype refinement — before user retest
b3ba0a7f prototype passed532inputs/focused62/full3245/0/build/package. Old22792 normalQuit/exactabsence, new prototype opened using249freshownedfixtures only; LibraryOFF/historyOFF→ownLibraryON/Saved/historyOFF. Native search input/space/Backspace worked and active localstroke was visible. However forced legacy draw mode showed a clipped search glyph and oversized focus frame around intrinsic bezel; not acceptable to hand off as final. Source now preserves native rendering and uses a local noninteractive child/layer border fitted to intrinsic height. Default cards and paging untouched. First prototype has NOT been physically accepted; previous full/build evidence is historical during this refinement.

## Overlay refinement checkpoint
Ten localfocus tests + existing owner/view/preview tests: focused63/0 on refined source. Frozen532r2; only source delta relative to galleryr2 remains3files. Independent Mill BOUNDED SOURCE ACCEPT for local child/layer/native rendering parity,10test definitions and actual editor-handoff integration; final hashes rechecked, all agents closed. Full/build/package r2 serial in progress. No visual/physical pass transferred from the rejected legacy-render prototype.

## Final delivery checkpoint

# Library local focus — final source/native handoff

Date:2026-10-19. User's original physical FAIL remains preserved at .build/verification/20261019/library-focus-local/user-regression-r1.json.

## Delivery
- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-focus-local-rc-20261019-r2/LaunchcopyUITest.app`
- Executable SHA256: `a7509311dd1aff1b1d7b7d794be5bbc95d273eeb2dceb0f35a18ba373a543c3c`; running owned PID41393; unsigned/uninstalled.
-532frozeninputs unchanged after native work. Focused63/0, full3246/0, Debug/Release/package/diff passed; packaged365keys×3languages. Initial recompilation emitted unrelated existing conditional-cast/weak-mutability warnings; no global warning-clean claim.
- Independent Mill BOUNDED SOURCE ACCEPT on final local-child overlay/native rendering strategy; all agents closed. No formal whole-project Reviewer/physical PASS.

## Final implementation
Only3source/test files differ from galleryr2: AppLibraryView.swift plus newLibrarySearchField.swift and LibrarySearchFocusDrawingTests.swift. The Library search/control cell use no default external focus ring; a noninteractive AX-hidden child with2ptlayerborder supplies visible key-window focus. Its frame is local, contained and fitted to native intrinsic bezel height; ancestor transforms/removal own its lifetime. Native NSSearchField rendering mode/editor/input/AXidentity are retained. Native key/edit/window-update notifications reconcile state without a timer or unconditional redraw. Other controls keep native focus. Cards/parent navigator/PagingCore/thresholds/data are unchanged. Ten new deterministic tests include actual native editor handoff via the real notification observer, sibling marked-text preservation and noninteractive contained decoration.

## Native proof
Old22792 normalQuit/exactabsence, internal37397prototype normalQuit/exactabsence, finalcandidate CUAopened. Fresh249hashverified ownfixtures only,80copied synthetic appcategories; no preference/history/cache imports. LibraryOFF/historyOFF observed→ownLibraryON/nativeSaved/historyOFF. Source/binary/249seed hashes rechecked unchanged. Native search query→onefixture result, space/Backspace and clear action→cards; active screenshot shows complete magnifier and a thin, fitted border (the rejected forced-draw prototype's clipped glyph/loose frame not carried forward). NativeBack closes Library; active main screenshot shows only its intentional small native search ring, no wide Library ring in that ordinary-return path. WallpaperREADY. No real app launch, removal, formaldata, OSchange or saved private screenshot.

## Honest remaining gates
One generated horizontal scroll had no observed navigation; inconclusive, not physical/swipe PASS. One generated Escape after clear had no observed exit; nativeBack then closed; no native Escape acceptance inferred. LiveIME, spokenVoiceOver, canceled/swipe/momentum/120Hz and frame timings untested. Raw AX-hidden flags do not prove spoken exclusion. The requested completed real-touchpad swipe remnant remains USER_RETEST_PENDING, not repaired-by-test-count. Root compositor cause unproven; replacing its suspected external drawing path is not a causal diagnosis.

## Current handoff
Mainfirstpage/emptyquery, SettingsfolderLibraryclosed, ordinarynon-topmostwindow, wallpaperREADY, ownLibraryON/historyOFF. Request one user physical enter/return and stop UIcontrol while they perform it. If it persists, distinguish starting responder and outline geometry using permitted native observations before broadening scope. Full product objective remains incomplete.

## 2026-10-20 scoped human acceptance

User confirmed “宽蓝框不再残留” for the a7509311 final local-overlay candidate after completed real two-finger entry/return. This supersedes USER_RETEST_PENDING for that remnant only. Original regression remains historical. New reports of entry hitch and return flicker are separate defects, not reversal of this focus-border acceptance. Receipt: `.build/verification/20261019/library-focus-local/human-acceptance-20261020.json`.
