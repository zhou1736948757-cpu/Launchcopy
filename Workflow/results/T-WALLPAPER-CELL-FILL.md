# T-WALLPAPER-CELL-FILL — Worker Result

- Date: 2026-09-11, Asia/Shanghai
- Status: Implemented and targeted tests completed; independent review pending. Not a formal PASS.
- HEAD: `6382bd911741831d13360e402c270bb6509b3679`, `main...origin/main`.
- Build resource released to Main after the test process exited at 21:35:03. No further Worker builds planned.

## Changes and scope

Exactly two production lines changed:

1. `Sources/AppGridUI/AppGridCellView.swift`: initial layer background becomes `nil`.
2. `Sources/AppGridUI/AppGridCellFocus.swift`: unfocused layer background becomes `nil`.

Selected fill, accent ring, accessibility focus setters, frames, hitTest, drag paths, folder binding and identity are unchanged. No new styling subsystem.

Additional changed files:

- `Tests/AppGridUITests/CellBackdropTransparencyTests.swift` (new).
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift`: Main explicitly amended scope to permit only the three idle-background assertions. Each now requires nil with an explanation of the transparent-idle requirement. Existing focus, content and reuse assertions remain intact.
- `Workflow/results/T-WALLPAPER-CELL-FILL.md` (this result).
- `Workflow/artifacts/T-WALLPAPER-CELL-FILL/`: two test logs and twelve synthetic PNGs.

Prior PageHostView repair preserved; its before/after-this-task SHA-256 is unchanged:
`b552714856e3d1ebb3a22691580136f479e0ed8531436308e0d8a9724a84bcef`.
All unrelated working-tree changes were preserved. Initial Git diff for the two cell sources was empty.

## Synthetic fail-before / pass-after

The same new tests were run before and after the production edit, without changing their expectations. A real AppGridCellView is attached over an in-memory saturated red NSView backdrop and captured with `bitmapImageRepForCachingDisplay` / `cacheDisplay`. Samples are taken at x=10pt, vertical midpoint in a 120x96pt cell: padding away from icon, labels, corners and border. No real wallpaper or user image is accessed.

Six sampled states: initial, unfocused after focus, cleared after focus, folder bind, folder unfocused, and app rebound from focused folder.

Before command (cwd: repository root; executed through `rtk proxy`):

```sh
PAGING_CELL_ARTIFACT_DIR="$PWD/Workflow/artifacts/T-WALLPAPER-CELL-FILL" \
PAGING_CELL_ARTIFACT_LABEL=before \
swift test --jobs 1 --filter CellBackdropTransparencyTests
```

- Valid test execution at 21:33:07–21:33:08: 3 tests failed, 24 assertion failures, exit 1.
- All six padding samples were device RGB approximately `(0.118637, 0.118637, 0.118637)` rather than red.
- Log: `Workflow/artifacts/T-WALLPAPER-CELL-FILL/fail-before.log`.
- Images: `before-{initial,unfocused,cleared,folder,folder-unfocused,rebound-app}.png` in the matching artifact directory.
- An earlier sandbox attempt did not execute tests: clang ModuleCache output was denied. The command was rerun with escalation; the log above is the valid execution, not the sandbox failure.

After / targeted command:

```sh
PAGING_CELL_ARTIFACT_DIR="$PWD/Workflow/artifacts/T-WALLPAPER-CELL-FILL" \
PAGING_CELL_ARTIFACT_LABEL=after \
swift test --jobs 1 \
  --filter '(CellBackdropTransparencyTests|AppGridCellFocusReuseTests|FolderCellTests)'
```

- Serial, escalated execution; completed 21:35:03, exit 0.
- CellBackdropTransparencyTests: 3/3.
- AppGridCellFocusReuseTests: 3/3.
- FolderCellTests: 9/9.
- Total: **15 tests, 0 failures**. The separate Swift Testing footer with zero tests is not the XCTest count.
- All six padding samples became device RGB approximately `(0.998450, 0.146943, 0.000110)`; the same red-dominance assertions passed. The helper uses a dominance threshold to tolerate color-space conversion rather than assuming exact raw RGB bytes.
- Log: `Workflow/artifacts/T-WALLPAPER-CELL-FILL/pass-after-targeted.log`.
- Images: `after-{initial,unfocused,cleared,folder,folder-unfocused,rebound-app}.png`.
- Worker visually inspected before-folder.png and after-folder.png: dark rounded tile removed, folder symbol/title/count still visible over synthetic red.

## Regression boundaries

- New tests retain checks for selected background, 3pt accent ring, focus reset, binding tokens, folder symbol/count/role/label, and app rebind cleanup.
- Existing FolderCellTests cover folder accessibility, click callback identity, icon rejection and reuse. Accessibility focus setter code was not changed; live assistive-technology focus was not exercised.
- `git diff --check` succeeded. Source diff confirms exactly two production-line substitutions; no input/hit geometry changes.
- Full suite and Release are Main-owned, not run here. Task packet reports a prior full-suite baseline of 12 failed assertions across 7 cases; this Worker neither reran nor altered those unrelated expectations.
- No real image/path reads, LaunchBetter/Buho access, GUI activation, process termination, packaging, signing, commit or push.
- Synthetic compositing is verified; real candidate GUI and independent review remain separate gates. Main owns both next steps.

## Source hashes at handoff

- AppGridCellView.swift: `8056b97b7800c470b8af82c1a107ffe42ce1d93ccc1c191af4c6e14dc5661c53`
- AppGridCellFocus.swift: `32e5148322f63878f9dfc69d0f7da53b995b99fdcaa57728e7c3286bc6287551`
