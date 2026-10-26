# Spacious main grid with independent large-icon preference

Date:2026-10-19
Status: SELECTED_IMPLEMENTATION under explicit human visual correction and routine-decision autonomy. Human aesthetic acceptance remains pending.

## Problem / intended outcome
Human rejects width-only128pt cell cap: icons remain small and are bunched in the center. Restore use of available main-page width and supply genuinely larger main glyphs, initially80pt for a clean test profile. Fix both horizontal spread and vertical icon budget, not a drawing transform detached from interaction frames. This continues the full independent LaunchBetter UI/functions goal on Launchcopy, not a new application or an iOS clone.

## Scope and non-goals
Main page only. Preserve logical3…8rows/columns, default5columns7rows, canonical order, full/partial/search centering semantics, search/launch/keyboard, pager/gesture/frame parameters, folder layout/material/inner pager, reference exclusions and formal user data. No automatic density reduction, hidden scaling of saved point sizes, icon asset import, new global monitor, OS/security change, signing/install/publication or Git history operations.

## Preferences and compatibility
Retain existing preferredIconSide32…64/font9…16 as the base/folder appearance with unchanged meaning. Add optional mainPreferredIconSide32…96. A missing override in legacy schema1/2 follows the old explicit base size, preserving old48/54/64 values. New clean-profile/factory default chooses main80 with base/folder48 and font11. Main resolution returns a GridItemAppearance with override-or-base; folder resolution remains the existing itemAppearance. Domain GridItemAppearance can represent up to96, but the legacy/base preference remains validated32…64. Do not clamp/secretly reinterpret folder values.

Save appearance schema3; support1/2 read without writing or repairing, reject invalid legacy fields including old out-of-range base values, recognize future version before decoding body and refuse overwrite. Preserve unsupported/corrupt/recovery/actual-receipt/Quit safeguards. No migration writes on load, close or resize. Old builds must see schema3 as future, rather than silently discard the new field. Only explicit accepted edits/default recovery save the new schema.

## Settings contract
Add a clearly labeled main-page icon slider32…96; retain the existing32…64 base/folder slider, label it accurately. New clean draft shows80 main /48 folder. Legacy nil override displays inherited main size; moving only the main slider sets an explicit override. Other controls preserve nil or the current override rather than recreating/dropping it. Keep live/coalesced save, safe interaction deferral, merged row/column controls, future/corrupt protection and independent receipts. Explain that dense selected grids can fit less than preferred. Show computed APP/FOLDER-entry fitted main sizes for the current viewport when owner can resolve it; this is candidate geometry, not a saved/render receipt. No forced enlargement or capacity change.

## Shared geometry decisions
Remove fixed128pt maximum main column width. Keep existing side/top/bottom area and actual spacing. Introduce one small MainGridLayoutMetrics policy for preferred main cell height based on resolved main size, measured name/count line boxes and explicit content padding; do not change AppGridGeometry's ordinary default88pt contract for other direct callers.

Add an explicit content layout context, defaultstandard, to shared GridItemContentGeometry. Standard/folder geometry remains byte-behavior equivalent. Main-grid context centers its icon/caption stack in the actual cell with2pt top/bottom minimum padding and4pt icon-caption gap, fitting side to available width/height. Name/count remain bounded with truthful empty icon in insufficient space. No font scaling to hide density. Preferred main height=max(88, preferred side+measured folder name/count+8). Five rows in700pt content leave580pt and at most116pt per row:80pt plus current12pt-font folder captions28+8 fits, whereas96pt may fit smaller. Existing readability24pt is only the admission guard, not a preference fulfillment proof.

AppGridPageView sets main context on its cells and requests layout when main appearance changes; FolderOverlayView keepsstandard. Renderer, MainGridReadability, page-dot gutter and settings fit feedback all use the SAME main metrics. Actual cell/glyph frames remain the authority for hit tests, drag/drop and folder source conversions. No guessed source origin from a preference.

Drag previews capture source context, actual glyph side and bounded caption budget; do not squeeze an80pt source into the old96x88 preview. Preserve durable captured content on move-out and standard folder preview behavior. No source-cell lifetime dependence after capture.

## Icon quality and performance
Do not change the icon request key or cache policy merely because its nominal default says48pt. Read-only audit found SystemIconLoader retains images up to256px;192px covers96pt at2x in principle. Existing pipeline stays unchanged; actual low-resolution source quality remains visual evidence, not guaranteed from this arithmetic. No per-frame persistence/rebinding/icon request, new blur/compositing effects, extra pager or animation. Layout/resize/preferences perform bounded arithmetic only; keep current safe presentation gates and cache/concurrency bounds.

## Ownership and verification
Main owns MainGridLayoutMetrics, geometry withdrawal/main-cell wiring, readability, AppDelegate composition/page dots, DragUIVisuals and their new bounded tests. Foundation worker owns GridItemAppearance.swift (value/context geometry), AppearancePreferences.swift (schema/override resolution), GridItemAppearanceTests/AppearancePreferencesTests plus bounded new foundation tests. UI/localization worker owns AppearanceSettingsView, localization keys/fallback/three resource files and new main-size UI tests only. No shared writable files; at most3active agents includingMain; tests/builds serialized byMain after integration. Workers return file lists; independent review follows stable diff. No historical Chef workflow reinstatement.

Focused requirements: explicit80/96 validity; base65 invalid; legacy1/2 same meaning/no writes; schema3 roundtrip/future protection and unrelated edits preserve override; standard folder geometry unchanged; main80pt fits1000x700/6x5/currentfont12; full/partial/search/nonzeroorigin/narrow windows; shared readability/dots/drag/source frames; preview retains80pt glyph and does not request/rebind icons. Capture intentional old-default/schema assertion adaptations; no broad test weakening. Full nonzero suite, Debug/actualRelease, package localization/native-entry checks and new exact source/hash receipt required. Native ordinary isolated profile verifies spread, main80/base48 independence, source folder open/close, search and saved restart. Human aesthetic, physical paging/hitch,120Hz/multidisplay/realIME/VoiceOver remain distinct.

## Risks / delivery
Large icons cannot all fit arbitrary8x8small windows; retain preferred size and existing protection, show actual fit rather than silently alter rows. Larger preferred main size can increase vertical group height and page-dot gutter changes; consumers must share metrics. Long-name truncation and app transparent padding remain visible considerations. Preserve all dirty history/previous candidates and old formal data. Previous128pt design and its candidate are rejected, not a recommended latest build. Deliver a fresh unsigned isolated candidate only after new evidence; do not relabel old3101green or old native as proof of this revision.

## Review-driven projection correction

Initialindependentreviewfoundfitprojectionmustusecurrentselectedcapacitydraft,notoldpresentedcapacity,whilerowpresentationisqueued. Main reproduced1test/3failedassertions and fixedwithprojection-onlydraftobserver+weakcurrentviewprovider+attach/reload/defaultrefresh,withoutstorageacknowledgment. Finalteardownguardprecedesfitrefresh. PascalboundedrepairSOURCEACCEPT; finalfrozenverificationstillrequired.

## Design-reference boundary
Consulted Apple's public Layout guidance (https://developer.apple.com/design/human-interface-guidelines/layout) for adaptive layout, safe areas and checking multiple window sizes. This is principle-level guidance, not a measured iOS Home Screen grid specification:80pt is our desktop starting preference, not an Apple-prescribed ratio. No third-party source/assets imported.

## Delivery checkpoint
Frozen r3 focused62/0, full3131/0, Debug/actualRelease/package and365-key×3packaged resource checks passed. Native6×5/main80/base48/source-folder/ESC/search/liveindependence/restart checks observed in an ordinary isolated window; candidate suffixr2/PID72970 left running. User aesthetic acceptance remains pending. See final results for exact hash, chronology and explicit wallpaper/physical limits.

## 2026-10-19 explicit folder-content refinement supersession
The user additionally requested folder layout refinement. `FOLDER_MEMBER_LAYOUT_REFINEMENT_SPEC.md` now supersedes the prior instruction that real folder members keep standard cell content placement: real/reused/swipe folder members use explicit centered folderGrid context with6pt padding/gap, preserving measured labels, saved size preferences and actual-fit previews. Standard direct callers and main default geometry remain unchanged. This does NOT change accepted panel ratios/max5×3/inner capacity/data/paging/motion or default48 preference. Current own demo uses an explicitly saved64 test preference, not a new product default. See final results for519inputs/61focused/3147full and native evidence limits.
