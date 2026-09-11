# T-A4-0ms — Review r1

**Reviewer**: independent Reviewer (chef-worker-reviewer-workflow)
**Date**: 2026-08-30
**Scope**: verify Worker claims for task T-A4-0ms (production default `Timer.tolerance` 4ms → 0ms)
**Mode**: READ-ONLY (no implementation files edited)

---

## Verdict: **APPROVE (PASS)**

All Worker claims verified independently. No BLOCKER, no MAJOR. Two MINOR observations (both non-blocking, one is an interpretation question about the "anywhere" grep).

---

## 1. Code defaults — VERIFIED

| File | Line | Value | Status |
|---|---|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | 60 | `tolerance: TimeInterval = 0` (init default) | ✓ |
| `Sources/PagingUI/PagingFrameDriver.swift` | 134 | `timer.tolerance = tolerance` (comment updated to 0ms) | ✓ |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 100 | `?? 0` (frame-driver default, seconds) | ✓ |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 443 | `?? 0.0` (SELFDRIVE print, ms) | ✓ |
| `Sources/PagingPrototypeApp/FrameDriverExperiment.swift` | 130 | `frameTimerTolerance: TimeInterval = 0` | ✓ |

No live 8.333ms default remains anywhere reachable at runtime. `RunLoopFrameDriverTests.swift` (mtime 2026-08-29 13:35:43, predates task) uses only explicit tolerance values (0, 9) and asserts no default — consistent with Worker's "no change" claim.

## 2. CLI untouched — VERIFIED

`AppArguments.swift:267` — `--frame-timer-tolerance-ms` legal range still `value >= 0, value <= 16.667`; parsing logic unchanged. Three stale 8.333ms texts updated to 0ms: header comment (:26–27), `frameTimerToleranceMS` doc (:98), `--help` text (:325–326). ✓

## 3. Forbidden trees — VERIFIED (mtimes unchanged)

All 8 forbidden files' mtimes match the Worker's recorded before/after values exactly (my independent `stat`):

| File | mtime (epoch) | mtime (date) | Match |
|---|---|---|---|
| `Package.swift` | 1787917375 | 2026-08-28 20:42:55 | ✓ |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | 1787921214 | 2026-08-28 21:46:54 | ✓ |
| `Sources/PagingCore/PagingState.swift` | 1787897056 | 2026-08-28 15:04:16 | ✓ |
| `Sources/PagingCore/TransitionContext.swift` | 1787900304 | 2026-08-28 15:58:24 | ✓ |
| `Sources/PagingCore/GestureSession.swift` | 1787903342 | 2026-08-28 16:49:02 | ✓ |
| `Sources/PagingCore/PagingCore.swift` | 1787905826 | 2026-08-28 17:30:26 | ✓ |
| `Sources/PagingCore/PageTargetPolicy.swift` | 1788005795 | 2026-08-29 21:16:35 | ✓ |
| `Sources/PagingCore/PagingParameters.swift` | 1788057962 | 2026-08-30 11:46:02 | ✓ |

## 4. Tests / builds — VERIFIED (my own measurements, run serially)

| Command | Result | Exit |
|---|---|---|
| `swift test` | **Executed 631 tests, with 0 failures (0 unexpected)** | 0 |
| `swift build -c debug` | Build complete | 0 |
| `swift build -c release` | Build complete | 0 |

`swift test` also emitted the swift-testing block `◇ Test run with 0 tests in 0 suites passed` — ignored per task convention; the XCTest "Executed 631 tests" line is authoritative. Matches Worker's claim of 631/0.

## 5. Grep — VERIFIED (with one interpretation note)

- `0.004`, `1.0/120.0`, `1_000.0/120.0` in the 3 source files: **0 hits** ✓
- `8.333` / `4ms` / `0.004` / `120.0` across the entire `Sources/` tree: **0 hits** ✓
- `PRODUCT_TIMER_TOLERANCE_4MS`: **0 hits in live state** (source code, MEMORY.md, PARAMETER_RATIONALE.md). It appears only in historical/planning/result documents:
  - `Docs/IMPLEMENTATION_LOG.md:354` — historical append-only log entry recording the prior T-A4 change (8.333ms → 4ms)
  - `Docs/FRAME_LAG_FIX_PLAN.md:319`, `Workflow/tasks/T-A4.md`, `Workflow/tasks/T-A4-0ms.md`, `Workflow/results/T-A4.md`, `Workflow/results/T-A4-0ms.md`, `Workflow/reviews/T-A4-r1.md` — planning/task/result artifacts

  See MINOR-1 / QUESTION-1 below.

## 6. No forbidden claims — VERIFIED

- `MEMORY.md:47` — `PRODUCT_TIMER_TOLERANCE_0MS`, long tail >25ms still `CAUSALITY_UNRESOLVED`, "不宣称已修复" ✓
- `MEMORY.md:118` — red-line updated to "不改生产默认 `Timer tolerance = 0ms`"; keeps `CAUSALITY_UNRESOLVED` / `PRODUCT_DEFAULT_UNCHANGED` ✓
- `Docs/PARAMETER_RATIONALE.md:44` — `timerTolerance | 0 ms | 0–16.667 ms | PRODUCT_DECISION | ... TUNING_REQUIRED（自动化 baseline 通过；物理门待 T-A5 物理验收 PASS）` ✓
- `Workflow/results/T-A4-0ms.md:67` — explicitly states no `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` ✓
- Other grep hits for forbidden tokens are in pre-existing plan/prompt/checkpoint docs that *discuss the rules* (e.g., "禁止 FIX_VALIDATED", "Do not treat this file as ROOT_CAUSE_FOUND") — not claims by this Worker.

## 7. No git operations — VERIFIED

- `git log`: "your current branch 'main' does not have any commits yet" (no commits) ✓
- `git diff --cached --stat`: empty (no staged changes) ✓
- `git status --short`: all files untracked (consistent with pre-task state) ✓

---

## Findings

### BLOCKER
None.

### MAJOR
None.

### MINOR
- **MINOR-1** — Task instruction #5 says "no `PRODUCT_TIMER_TOLERANCE_4MS` anywhere". Taken literally, this is not satisfied: `Docs/IMPLEMENTATION_LOG.md:354` retains the historical token in the append-only log entry for the prior T-A4 change. This is expected given the task's own file-change list (item 7) treats IMPLEMENTATION_LOG.md as append-only (add a line, don't rewrite history). No live/current-state file claims 4ms. Non-blocking; see QUESTION-1.
- **MINOR-2** — Task background note states "PagingCore last touched 2026-08-29 11:46", but the actual most-recent PagingCore mtime is `PagingParameters.swift` = 2026-08-30 11:46:02. This is a task-note typo (off by one day), not a Worker issue. The material fact — forbidden trees unchanged by T-A4-0ms — is verified.

### QUESTION
- **QUESTION-1** — Should the "no `PRODUCT_TIMER_TOLERANCE_4MS` anywhere" grep be scoped to live/current-state files (source + MEMORY.md + PARAMETER_RATIONALE.md), or does it literally include historical append-only logs and planning/result artifacts? If the latter, the historical IMPLEMENTATION_LOG.md:354 entry would need a decision on whether to annotate/rewrite history. Recommend: scope to live state; historical log entries are legitimate records.

---

## Deviations
None material. All Worker claims (631/0 tests, debug+release exit 0, forbidden-tree mtimes unchanged, no live stale defaults, no forbidden claims, no git operations) are accurate as measured.
