# T-A4 Review r1 — 生产默认 Timer.tolerance 8.333ms → 4ms

**Reviewer:** independent (read-only)
**Date:** 2026-08-30
**Scope:** verify Worker's T-A4 implementation independently; no implementation files edited.

## VERDICT: PASS

Production default `Timer.tolerance` is correctly changed to **4ms (0.004)** in both production
frame-driver paths. All tests/builds green, forbidden trees untouched, no privacy regression,
no forbidden claims. 3 MINOR documentation/latent-default consistency findings (no runtime
impact, no scope violation).

---

## Findings

### BLOCKER: 0

### MAJOR: 0

### MINOR: 3

1. **Latent live 8.333ms default remains — `Sources/PagingPrototypeApp/FrameDriverExperiment.swift:130`**
   `frameTimerTolerance: TimeInterval = 1.0 / 120.0` is still a live default (8.333ms).
   **No runtime effect**: the only construction site, `AppDelegate.swift:170`, always passes
   `frameTimerTolerance` (which defaults to `0.004`), so this default is never hit in the app.
   However, it contradicts the Worker's scope-verification claim that "the ONLY remaining
   references are comments/history/docs, not live defaults." Recommend updating to `0.004` for
   consistency (or documenting it as experiment-only).

2. **Stale CLI comments/help — `Sources/PagingPrototypeApp/AppArguments.swift:27, 98, 325`**
   Comments and `--help` text still state the CLI default is "8.333ms" / "nil = 保留默认
   8.333ms". Since `nil` now resolves to 4ms via `AppDelegate.swift:100` (`?? 0.004`), these
   are misleading. Comments only — no live behavior. (File mtime 08-29, not touched by T-A4.)

3. **Stale MEMORY.md red-line — `MEMORY.md:118`**
   Line 118 (from a prior phase) still reads "不改生产默认 `Timer tolerance = 8.333ms`",
   which now contradicts line 47 (default is 4ms, `PRODUCT_TIMER_TOLERANCE_4MS`). Historical
   instruction line left stale after the default change.

### QUESTION: 0

---

## Scope verification

**Live defaults (grep whole repo):**
- `1.0/120.0` in `.swift`: **none** (only `.md` history/plans/results).
- `1_000.0/120.0` in `.swift`: **none**.
- `8.333` in `.swift`: only comments — `AppArguments.swift:27,98,325` (stale, MINOR #2) and
  `FrameDriverExperiment.swift:130` is `1.0 / 120.0` (latent, MINOR #1).
- Production default confirmed **4ms** in both paths:
  - `PagingFrameDriver.swift:60` `tolerance: TimeInterval = 0.004` (init default).
  - `AppDelegate.swift:100` `?? 0.004` (assembly default); `:443` SELFDRIVE print `?? 4.0`.
- CLI explicit path & range unchanged: `AppArguments.swift:267` `value >= 0, value <= 16.667`.
- No other behavior change: frame source (RunLoop 60Hz), PagingCore, telemetry schema,
  animation params untouched.

**Forbidden trees (mtime):**
- `Sources/PagingCore/` — last file mtime 2026-08-30 11:46:02 (pre-T-A4). ✓ unchanged
- `Package.swift` — 2026-08-28 20:42:55. ✓ unchanged
- `Sources/PagingPrototypeApp/AppLaunchController.swift` — 2026-08-28 21:46:54. ✓ unchanged
- Only files touched at T-A4 time (14:51): `PagingFrameDriver.swift` (14:51:08),
  `AppDelegate.swift` (14:51:10). ✓

**Tests file:** `Tests/PagingUITests/RunLoopFrameDriverTests.swift` mtime 08-29, only explicit
`tolerance: 0` / `tolerance: 9` asserts, no default assertion. ✓ unchanged.

**Docs consistency:**
- `Docs/PARAMETER_RATIONALE.md:44` — `timerTolerance | 4 ms | 0–16.667 ms | PRODUCT_DECISION |
  ... 改为 4ms ... | TUNING_REQUIRED（物理门待 T-A5 物理验收 PASS）`. ✓ matches code (0.004).
- `MEMORY.md:47` — `PRODUCT_TIMER_TOLERANCE_4MS`, long tail >25ms still `CAUSALITY_UNRESOLVED`,
  no fix claim. ✓
- `Docs/IMPLEMENTATION_LOG.md:352-354` — T-A4 line appended. ✓
- No forbidden claims (`ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` /
  `SHORT_TAIL_MITIGATED_BY_TOLERANCE`) in changed files. Only a pre-existing prohibition line
  (`IMPLEMENTATION_LOG.md:318`). ✓

**Privacy:** no global `NSEvent` monitor / Accessibility / sync I/O / app-name/bundleID/path/URL
leakage in new/changed code. The only `NSEvent` references in `AppDelegate.swift` are a comment
(`:577`) and a pre-existing window-level `sendEvent` override (`:592`), neither part of T-A4. ✓

---

## Measured test/build results (run by reviewer)

- `swift test` → **Executed 631 tests, with 0 failures** (0 unexpected) in ~21s.
  (The trailing "0 tests in 0 suites" is the swift-testing library — expected, ignored.)
- `swift build -c debug` → **exit 0** ("Build complete!").
- `swift build -c release` → **exit 0** ("Build complete!").
- `git status` → no commits yet, no git operations performed by Worker. ✓

---

## Conclusion

The production default `Timer.tolerance` is correctly 4ms in both production frame-driver paths,
with all tests (631/0) and both builds (debug/release exit 0) passing. Forbidden trees
(PagingCore, Package.swift, AppLaunchController) are untouched; no privacy regression; no
forbidden claims. The 3 MINOR findings are documentation/latent-default consistency issues with
no runtime impact. **PASS** — can proceed to Main for rebuild/relaunch and user physical
verification (T-A5 gate remains TUNING_REQUIRED).
