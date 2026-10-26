# Folder inline rename and intermittent pointer ownership — 2026-10-24

## Problem and intended outcome
The user reports a full-width folder rename field, outside clicks not ending editing, and intermittent main/folder dragging after the no-change idle repair. Preserve independent Swift/AppKit implementation and existing paging/appearance/organization contracts.

## Rename requirements and decisions
- Use the same 22pt semibold typography and centered title position as the visible folder name; compact text-measured editor with small caret/bezel padding, bounded by available title space, never a full-panel bar for short names.
- Grow/shrink the editor as text changes within bounds, without moving the panel or icons, rebuilding members or forcing an IME composition commit. Empty draft retains usable caret width; long titles scroll within a bounded editor.
- A left click in the same launcher content outside the mounted editor negotiates normal field-editor resignation and commits through the existing guarded rename owner exactly once. Consume the entire dismissal pointer sequence so the same click cannot launch an app, close the folder, move an item or reopen editing. Clicking inside the editor continues native selection/composition; Enter commits and Escape cancels unchanged. Native window title/resize and other windows retain normal behavior. Resignation refusal keeps editing and still consumes the outside click; do not force-unmark IME.
- Existing focus loss, stale generation, layout/store epoch, read-only/quit safety and cancellation semantics remain authoritative. No direct persistence or broad event monitor.

## Drag investigation
Treat previous idle cancellation fix as a proven partial defect, not sole physical causality. Audit native down/drag/up ownership, first-mouse, folder transition and title-edit gates, source-hit geometry and cancellation. Add deterministic regressions before any repair. Do not loosen generation safety or synthesize missing downs. If deterministic source proof is unavailable, add bounded opt-in identity-free diagnostic counters/report in the isolated preview rather than claiming root cause.

## Architecture / ownership
Main owns inline editor/layout/window admission, AppDelegate integration and tests/build/package/native handover. One read-only drag admission sidecar audits separate ownership/cancellation paths with concrete code references, no shared writes/tests/UI. At most3active includingMain; independent bounded review after stable inputs. Existing old workflow/watchdog remains bypassed by user.

## Validation / delivery
Test compact title font/geometry, short/long/empty/Unicode typing and resize, one-time outside commit and full sequence consumption, inside input, cancellation/refusal and inactive title state; preserve existing rename lifecycle/search/drag tests. For drag fixes use concrete reproduction and retain red evidence. Positive-count focused/full XCTest, Debug/Release/strict package and independent review. Deliver a unique same-profile unsigned sibling, normal Quit only owned89871after gates, preserve current arrangement/preferences and original manifest. Native presentation is separate from user physical intermittent-drag acceptance. No real-app agent drag/launch, forbidden reference reads, Git mutation/forced exit/install/sign/publish.

## Unresolved gates
Physical intermittent drag sequence/cause; native IME and full parity are unproven. User did not accept previous first-drag repair as complete; newest report supersedes any inference of physical PASS.

## Drag audit decision
Readonly Nash found no sole physical cause. Existing input paths have several independently plausible admission gates; preserve them rather than guess. Add default-OFF, isolated-preview-only in-memory fixed-enum counters for native routing/admission/cancellation/release/outcome, explicitly started/reset through native View menu and shown in a neutral report. No raw touches/events/coordinates/identities/history/IO/telemetry or behavior-changing E4 probe.

One concrete safety defect can be repaired independently: a valid down followed by a distant up without a processed moved event must not be reported as a click/launch. Reuse the existing6pt threshold, finish as no-op without synthesizing drag/commit; normal close releases still click. This does not claim missing movement delivery is fixed or that this sequence occurred physically. Add pure main/folder regressions before repair.
