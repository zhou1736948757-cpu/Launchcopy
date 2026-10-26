# T-WALLPAPER-OCCLUSION Worker Result

- Date: 2026-09-11
- Role: Worker
- Status: Implementation and targeted verification complete; independent Reviewer verdict pending
- Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
- Actual baseline: `6382bd911741831d13360e402c270bb6509b3679` (`main...origin/main`)

## Scope and repository state

The task packet's corrected Git baseline was confirmed before editing. The working tree already contained Main-owned changes in `Workflow/STATE.json`, `Workflow/events.jsonl`, `Workflow/heartbeats.json`, and `Workflow/watchdog.json`, plus untracked task/stage/artifact files. Those changes were preserved. No reset, cleanup, process operation, GUI activation, packaging, wallpaper access, or LaunchBetter/Buho access was performed.

Worker-owned changed paths:

- `Sources/PagingUI/PageHostView.swift`
- `Tests/PagingUITests/PageHostBackdropTests.swift` (new)
- `Workflow/results/T-WALLPAPER-OCCLUSION.md` (new)
- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/`

No `Package.swift`, `PagingCore`, provider, `AppDelegate`, packaging, input, or other product source was changed.

## Fail-before proof

The baseline source snapshot was already present at:

- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/PageHostView.before.swift`
- SHA-256: `acee7c804ce7ce71325c902f1316736be2766ff92b8a357770b1758029a9a83d`
- It matched the pre-edit `Sources/PagingUI/PageHostView.swift` hash exactly.

Command, run serially after the Swift/clang cache required sandbox escalation:

```bash
PAGING_BACKDROP_ARTIFACT_DIR="$PWD/Workflow/artifacts/T-WALLPAPER-OCCLUSION" \
PAGING_BACKDROP_ARTIFACT_LABEL="fail-before" \
swift test --jobs 1 \
  --filter 'PageHostBackdropTests/testSyntheticBackdropRemainsVisibleThroughCustomRendererHost'
```

Observed result:

- Build completed.
- Executed 1 XCTest.
- Failed with 4 assertions, including a non-nil opaque host background.
- Rendered center pixel: RGBA `(23, 23, 23, 255)`.
- The saturated red synthetic backdrop appeared only outside the host's rounded corners, while the real `PageHostView` covered its interior with `controlBackgroundColor`.

Evidence:

- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/fail-before.log`
- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/fail-before-synthetic-backdrop.png`

This proves the page-host fill could occlude a valid backdrop without relying on the handoff hypothesis or reading real wallpaper data.

## Implementation

`PageHostView` now applies a renderer-dependent host appearance:

- `customRenderer != nil`: the host layer has no background fill, allowing the window backdrop to remain visible through the presentation host.
- `customRenderer == nil`: the original `controlBackgroundColor` remains for the neutral laboratory renderer.

The policy is applied both when `customRenderer` changes and at the start of `render(...)`. Existing border width, border color, corner radius, renderer binding, view attachment, layout, reuse generation, and input behavior were left unchanged.

The source diff is 13 insertions and 2 deletions. Current source SHA-256:

- `Sources/PagingUI/PageHostView.swift`: `b552714856e3d1ebb3a22691580136f479e0ed8531436308e0d8a9724a84bcef`

## Pass-after synthetic regression

Command:

```bash
PAGING_BACKDROP_ARTIFACT_DIR="$PWD/Workflow/artifacts/T-WALLPAPER-OCCLUSION" \
PAGING_BACKDROP_ARTIFACT_LABEL="pass-after" \
swift test --jobs 1 --filter 'PageHostBackdropTests'
```

Observed result:

- Executed 3 XCTest tests.
- 3 passed, 0 failed.
- Rendered center pixel: RGBA `(251, 0, 7, 255)`.

Coverage:

1. A non-`NSView` renderer implementing `PagingPageRenderingTargetBinding`, matching the production AppGridRenderer shape, receives the real host as `renderTarget` while the synthetic red backdrop remains visible.
2. An `NSView` custom renderer remains correctly attached and sized after resize and `clearForReuse()`/re-render; reuse generation and clear invocation remain intact; the host stays transparent.
3. The nil/custom-free neutral renderer path still creates neutral content and retains the existing host background, border width, and corner radius.

Evidence:

- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/pass-after.log`
- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/pass-after-synthetic-backdrop.png`

## Targeted regression

Command:

```bash
swift test --jobs 1 \
  --filter '(PageHostBackdropTests|PagingSeamTests|AppCatalogAssemblyTests)'
```

Observed result:

- `PageHostBackdropTests`: 3/3 passed.
- `PagingSeamTests`: 15/15 passed.
- `AppCatalogAssemblyTests`: 6/6 passed.
- Total: 24 tests executed, 24 passed, 0 failed.

This set exercises the new pixel regression, host resize/reuse, neutral rendering, seam generation/recycling, and the real AppCatalog renderer assembly using synthetic fixtures.

Evidence:

- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/targeted-regression.log`

`git diff --check` completed successfully.

## Artifact hashes

- `fail-before-synthetic-backdrop.png`: `bcf890f1e42d43edb533a843fbe4c6c9797053a2dbf2a46bf39164b62ae576d6`
- `pass-after-synthetic-backdrop.png`: `c0217e7a6d64ea0ef477d4e755c81854f190f378e22652339afd871342b4d331`
- `fail-before.log`: `11f71885b2100b3b8930167c46f6498ca71cd75443cf529dbbf8e0515872bb7e`
- `pass-after.log`: `1435dc92cfd188efb2a5ce0520cc40336ae29e75f3275b014924630f52ecdf07`
- `targeted-regression.log`: `634794646acf4783800398da651cb6c00b8d40a69a545208b47a2b04e7bff75f`

## Limitations and remaining gates

- The synthetic pixel test proves host compositing behavior; it does not prove the packaged application displays the user's real wallpaper.
- No real wallpaper path or pixels were read.
- The running GUI application was not modified, relaunched, activated, or terminated.
- No full test suite, Release build, packaging, signing, or candidate installation was performed by this Worker; Main owns those steps.
- User physical/GUI acceptance remains separate.
- This Worker does not self-certify formal `PASS`; independent Reviewer judgment is required.

Build/test resource ownership is relinquished to Main after the targeted regression above.
