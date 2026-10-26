# Folder Viewport Fit: Bounded Source Review

Reviewed 2026-10-14. Verdict: **SOURCE_REVIEW_CLEAR** for the restored vertical
layout repair; no blocking implementation finding in the assigned delta.
This is source review, not GUI, performance, whole-product or candidate acceptance.

## Scope and authority

- Swift/AppKit, existing manual NSView frame layout in `AppGridUI`.
- Implementation scope: `FolderOverlayView.layoutPanel`, rows/pitch/height/y only.
- Main owns repair, serialized Swift execution and verification; no agents dispatched.
- Only this document was written. No implementation/test edits, test/build/app runs,
  process changes, commits or dirty-tree cleanup were performed by this reviewer.
- Global parity and automatic-fit scalar settings are approved. Adjustable capacity
  and Library-specific contracts remain unapproved; this is an existing-layout bug fix.
- Read both the current stage and prior icon/type closeout. Its 2159/0 result is
  historical coverage before this repair, not validation of these changed bytes.
- HEAD is `319b8cc149a8553adfc3414abaacbe28b59d97ef`; the dirty working tree is
  authoritative. Its broader HEAD diff contains prior work outside this review.

## Findings and evidence correction

1. **Resolved test-oracle defect; original results remain historical.** The actual
   grid top is `ph - 40 - 24`, bottom is `44 + 12 = 56`, height is **ph - 120**.
   The initial fixture used `ph - 132`, shifting its expected top down by 12pt.
   `red.log` recorded 4 methods/272 failures at 00:48:24.817 JST; the exact-fit
   method failed there. `focused-r1.log` ended with 49 tests/101 failures at
   00:50:25.686 JST, all 101 in the viewport suite. These totals include incorrect
   area assertions; neither establishes an already-fit success or 272 real defects.
2. **Corrected reproduction confirms the real defect.** The current test uses
   `ph - 120`. `corrected-red.log` records 4 methods/191 assertion failures at
   00:53:11.379 JST, with the exact legacy-frame method passing. Main reports that
   only its own repair was temporarily reverted to the exact prior source for this
   run. The restored repair hash matches the originally reviewed repair exactly.
   The stage now appends a dated correction and retains the old records.
3. **Nonblocking coverage limits.** The four methods inspect real view frames,
   compact/partial pages and relayout tokens/generation/request counts. Despite its
   name, the relayout method does not directly assert page count or switch to page 1.
   Minimum-width panels, empty folders, threshold pitches 32/72, live pointer/drag,
   keyboard focus and pixel readability are not established by these methods.
   Source reasoning below covers geometry; these limits are not observed defects.

## Geometry and preserved layouts

For R = ceil(memberCount/5), A = ph - 120, the new pitch is
`p = min(104, max(A, 0)/max(R, 1))`, gap `g = min(16, p/2)`, height `h = p-g`.
For finite dimensions admitted by existing panel clamps, A >= 80: h is positive,
`h+g=p`, and the last row bottom is `gridTop-R*p >= 56` (roundoff aside).
Every row top stays below gridTop; successive rows have gap g and cannot overlap.
Partial last rows retain column order. Empty pages perform no cell-frame writes.

The old stride was `max(p-16,56)+16`. Every old fitting nonempty layout has
`A/R >= 72`, so p >= 72, g = 16 and h = p-16: width, height, x and y expressions
are identical. The repair therefore preserves all fitting frames, including the
full seven-row maximum panel; changes are confined to previously overflowing pages.

Arithmetic examples (panel-local coordinates, not a GUI or test run):

| Members / overlay | Panel | New height / gap | Last bottom, old -> new |
| --- | --- | --- | --- |
| 35 / 1000x600 | 700x480 | 35.429 / 16 | -88 -> 56 |
| 35 / 1470x956 | 900x700 | 66.857 / 16 | 56 -> 56, unchanged |
| 25 / 1470x956 | 900x700 | 88 / 16 | 116 -> 116, unchanged |
| 6 / 500x600 | 350x480 | 88 / 16 | 208 -> 208, unchanged |
| 35 / 500x500 | 350x400 | 24 / 16 | -168 -> 56 |
| 35 / 200x250 | 200x200 | 5.714 / 5.714 | -368 -> 56 |

Horizontal geometry stays `tileWidth=(pw-48-64)/5`, spacing 16, five columns.
At the existing 200pt panel minimum, width is 17.6pt, nonnegative and contained.
The 35-member capacity, outer panel, title/footer frames, motion/physics, bindings,
image keys and request paths are outside and unchanged by this vertical delta.
Tiny cells do not promise readable icons. Existing 200pt panel minima exceeding
a smaller overlay are explicitly outside scope; panel fit is not overlay fit.

## Regression boundaries and remaining gates

- Input: smaller frame-based activation/menu/press regions are intentional geometry
  consequences. Row gaps stay nonoverlapping; real compact-target usability is pending.
- Drag: current cells change source geometry; panel exit boundaries and thresholds
  are unchanged. Resize during a captured drag and drop targeting need runtime checks.
- Keyboard: member order/index/columns are unchanged. Focus-ring placement and
  compact-cell accessibility visibility still require keyboard/VoiceOver checks.
- Geometry: corrected exact-fit and compact assertions must finish against restored
  bytes. No new IO, scans, requests or scroll path appears in the reviewed arithmetic;
  this does not constitute measured performance evidence.
- Initially `focused-r2` was running. Final read-only log inspection records
  49 tests/0 failures at 00:54:44.298 JST; this reviewer did not execute that run.
  Main retains full/build and real GUI/physical gates. No candidate PASS.

## Read-only SHA-256 snapshot

`Sources/AppGridUI/FolderOverlayView.swift`: `3cf4e147f47907445a79d2fca48bc45be82e2dbedb17ac8ccc9f3938dd6bf6de`
`Tests/AppGridUITests/FolderViewportFitTests.swift`: `052bf418df342df72dc37707f9d4d268d437bfa0894027323054fb36dfc25fda`
`Workflow/stage-summaries/2026-10-14-folder-viewport-fit.md`: `b4716d815d9de6d501f77195bf0b950c01f1eaa15a979ba8000c617e6497d219`
`.build/verification/20261014/folder-viewport-fit/red.log`: `caa20d5d4411981c1d99eaf6c28852a52028a6a888ea660cc8d69daef67e6a56`
`.build/verification/20261014/folder-viewport-fit/focused-r1.log`: `d491db0d131ee1715554a160ba1f65de1c31d76866b0504a23809816341a6d09`
`.build/verification/20261014/folder-viewport-fit/corrected-red.log`: `a5e3938486ab9635965e4026c0475a634ee232d11b639f5f48bcc21325742d80`
`.build/verification/20261014/folder-viewport-fit/focused-r2.log`: `d7da732886accecd492e4ac4db5ad7a510775e3952c83cad8a6973b030cdb558`
