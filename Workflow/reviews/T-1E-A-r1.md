# Review Report: T-1E-A — Folder Domain Model + Lab Fixture + Focus-Identity Generalization

- **Reviewer**: independent Reviewer (chef-worker-reviewer-workflow v1.4.1)
- **Task**: T-1E-A
- **Date**: 2026-08-30
- **Verdict**: **PASS**
- **Findings**: 0 BLOCKER, 0 MAJOR, 1 MINOR, 2 QUESTION

---

## 1. Verdict

**PASS.** The Worker's implementation satisfies all acceptance criteria in `Workflow/tasks/T-1E-A.md`. All three documented deviations are safe. Full suite builds and tests pass with the claimed counts. Frozen trees are untouched. Privacy redline is clean.

---

## 2. Verification Evidence (measured independently)

| Check | Result |
|---|---|
| `swift build -c debug` | **exit 0** (Build complete) |
| `swift build -c release` | **exit 0** (Build complete) |
| `swift test` (full suite) | **660 tests, 0 failures (0 unexpected)**, exit 0. XCTest line: `Executed 660 tests, with 0 failures`. The swift-testing line `0 tests in 0 suites` is NOT the real count (it is the separate swift-testing framework run, which has no tests). |
| New tests (filtered run) | **27 tests, 0 failures**: `FolderDomainTests` 15, `FolderLabFixtureTests` 5, `AppGridFocusIdentityGeneralizationTests` 7. Matches Worker claim (baseline 633 + 27 = 660). |
| Frozen trees | All mtimes predate this task's work (see §4). |
| Read-only AppGridUI files | Untouched by this task (see §4). |

---

## 3. Acceptance Criteria Verification

### 3.1 FolderID — stable, non-name-derived, opaque Hashable ✅
`FolderDomain.swift:31-48` — `FolderID` wraps a `UUID` (`private let storage: UUID`), `Hashable, Sendable`. Never derived from title/name/path. `redactedDescription` returns the constant `"FolderID(<redacted>)"` (no raw). Tested: `testFolderIDRandomDistinct`, `testFolderIDDeterministicUUID`, `testFolderIDRedactedDescriptionHasNoRaw`.

### 3.2 FolderGeneration — separate monotonic latest-wins token; never mints/forges CatalogRevision ✅
`FolderDomain.swift:54-62` — `FolderGeneration` is an independent `UInt64` token (`zero`, `incremented()`, `Comparable`), exactly mirroring `AppSearchGeneration` (`AppSearchResultSet.swift:17-25`). Grep confirms the folder layer (`FolderDomain.swift`, `FolderLabFixture.swift`) references `CatalogRevision` **only in comments**, never in code — it cannot mint/forge a `CatalogRevision`. Tested: `testFolderGenerationZeroAndIncrement`.

### 3.3 Title normalization — trim / blank fallback / length cap / Unicode-safe ✅
`FolderDomain.swift:72-82` — `FolderTitle.normalized(_:fallback:)` trims `.whitespacesAndNewlines`, falls back when empty, truncates to `maxLength = 64` via `String(trimmed.prefix(maxLength))` (Character/grapheme-cluster based — never splits a grapheme). Tested: `testFolderTitleTrimsWhitespace`, `testFolderTitleBlankFallsBack`, `testFolderTitleTruncatesToMaxLength`, `testFolderTitleUnicodeSafeTruncation` (composed `e\u{301}` graphemes stay intact).

### 3.4 Membership rules — stable order, no duplicates; refresh member-shrink incl. single-member DISSOLVE ✅
- Dedup + stable order: `FolderEntryBuilder.make` (`FolderDomain.swift:104-111`) preserves input order, dedups via `Set<AppID>`. Tested: `testFolderEntryBuilderDedupsPreservingOrder`.
- Refresh member-shrink: `FolderMembership.rebase` (`FolderDomain.swift:204-225`) — removed members filtered out; empty folder → removed; **single-member folder → dissolved** (member becomes top-level app, folder removed); ≥2 kept. Tested: `testRebaseRemovesDeletedMembers`.
- Top-level composition: `TopLevelComposition.build` (`FolderDomain.swift:239-257`) — ≥2 → `.folder`; single → member as `.app` in ungrouped area; empty → nothing; ungrouped apps in catalog stable order. Tested: `testCompositionDissolvesSingleMemberAndDropsEmpty`, `testCompositionAllUngroupedWhenNoFolders`.
- **ADR-008 §2.4 (user decision 2026-08-30) implemented AND tested.** The lab fixture also includes single-member groups to exercise dissolve (`testEnabledGroupsByStableOrder` with 5 apps / groupSize 2 → last group single-member), per ADR §2.4.

### 3.5 TopLevelEntry (.app/.folder) + activation router — folder identity never routes to launch ✅
`FolderDomain.swift:137-184` — `TopLevelEntry` enum (`.app(AppRecord)` / `.folder(FolderEntry)`), `TopLevelEntryIdentity` (`.app(AppID)` / `.folder(FolderID)`), `ActivationRouter.decide` returns `.openFolder` for folder, `.launchApp` for app, `.reject` for nil. The app-launch path's `as? AppID` cast (`AppLaunchController.swift:131`) rejects any non-`AppID` identity — a `FolderID` can never pass launch validation. Tested: `testActivationRouterDecidesByEntry`, `testActivationRouterDecidesByIdentity`.

### 3.6 Lab fixture — default off, stable order first-N, neutral titles, no I/O ✅
`FolderLabFixture.swift` — `defaultEnabled = false`, `defaultGroupSize = 35`, `makeGroups` groups by stable catalog order (first N per group), neutral titles `Group 1`…, fresh `FolderID` per group, generation passed through. No I/O / no disk / no machine dependency (imports only `AppCatalogCore` + `Foundation`). Tested: `testDefaultDisabled`, `testDisabledReturnsNil`, `testEnabledGroupsByStableOrder`, `testEnabledEmptyCatalogReturnsEmptySnapshot`, `testInvalidGroupSizeReturnsNil`.

### 3.7 Focus-identity generalization — backward-compatible ✅
`AppGridFocusIdentity.swift` — `appID` is now a **computed property** derived from stored `entryIdentity: TopLevelEntryIdentity?`; the `appID:` constructors are retained. All existing call sites verified to behave identically:
- `.appID` reads: `AppGridFocusNavigator.swift:33`, `AppGridFocusLayout.swift:111`.
- `appID:` constructors: `AppGridFocusNavigator.swift:69`, `AppGridFocusLayout.swift:117,140`, `AppGridPageView.swift:120`, `KeyboardFocusController.swift:184,273`, `AppSearchController.swift:214`.
- `Hashable/Equatable` synthesized from stored properties; for app identities `entryIdentity == .app(appID)` is a bijection, so equality/hash semantics are preserved. Folder identity → `appID == nil` (rejected by launch path). Tested: `AppGridFocusIdentityGeneralizationTests` (7 tests) + full existing focus suite passes.

### 3.8 Privacy redline ✅
`FolderID.redactedDescription` is the constant `"FolderID(<redacted>)"`. Grep of the three new/modified source files found **no** `print`, `os_log`, `signpost`, `FileManager`, `UserDefaults`, `Data(write)`, `JSONEncoder`, `Telemetry`, `ProcessInfo`, `hostname`, `machine`, or `AppKit` (only comment mentions). The domain model has no telemetry calls; only neutral counters (`folderCount`, `memberCount`, `ActivationDecision` enum). No PagingTelemetry schema change. No real names/paths recorded.

---

## 4. Frozen-Tree Check

All frozen-tree files have mtimes **predating** this task's work (task source files written 16:12–16:14):

- `Sources/PagingUI/` newest = `PagingFrameDriver.swift` **15:15:30** (before 16:12; concurrent-worker file, not this task).
- `Sources/PagingCore/` newest = `PagingParameters.swift` 11:46:02.
- `Sources/AppCatalogCore/` = `AppCatalogCore.swift` 20:58:01 (Aug 28).
- `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/` — all ≤ 21:xx (Aug 28).
- `Package.swift` 20:42:55 (Aug 28); `Sources/PagingPrototypeApp/AppLaunchController.swift` 21:46:54 (Aug 28).

Read-only AppGridUI files (forbidden write scope): `AppGridUIPageContentProvider.swift` 16:04:49 (before this task's 16:12 — concurrent-worker change, not this task), all others ≤ 22:51 (Aug 28). Untouched by this task.

The Worker's only writes are the 3 allowed source files + 3 new test files, all within allowed write scope. No git operations performed.

---

## 5. Deviation Assessment (the 3 documented)

1. **`groupSize <= 0` returns `nil` defensively** — **SAFE.** `FolderLabFixture.makeGroups` guards `configuration.groupSize > 0` and returns `nil` rather than crashing. The task packet did not specify this case; a safe nil-degradation is reasonable and testable (`testInvalidGroupSizeReturnsNil`). No behavioral risk.
2. **Blank-title fallback caller-provided** — **SAFE.** `FolderTitle.normalized(_:fallback:)` takes the fallback as a parameter; the lab fixture passes `Group N`. The domain layer stays neutral (does not hardcode a fallback string). No behavioral risk.
3. **`appID` changed from stored `let` to computed property** — **SAFE.** Derived from `entryIdentity`; all existing call sites behave identically (verified above), `Hashable/Equatable` semantics preserved for app identities, and the full 660-test suite (including all existing focus/navigator/refresh tests) passes. No behavioral risk.

---

## 6. Findings

### BLOCKER
None.

### MAJOR
None.

### MINOR
- **M-1 — `FolderTitle.normalized` returns the fallback as-is (not trimmed/capped).** If a caller passed a blank or overlong fallback, it would not be normalized. No current behavioral risk (the lab fixture always passes a valid `Group N`), and the task only requires the *raw* title to be normalized. Recommend documenting or normalizing the fallback for robustness. Not blocking.

### QUESTION
- **Q-1 — `FolderEntry` has no ≥2-member invariant at construction.** A `FolderEntry` can be constructed directly with 0 or 1 members; the dissolve rule is enforced only at `FolderMembership.rebase` / `TopLevelComposition.build`. This is consistent with ADR-008 §2.4 (dissolve is a composition rule), so it is intended — confirming no invariant is expected at the value-type level.
- **Q-2 — `FolderGeneration.incremented()` can overflow at `UInt64.max`.** This exactly mirrors the established `CatalogRevision` / `AppSearchGeneration` pattern, so it is consistent with existing code and not a practical risk. No action required.

---

## 7. Conclusion

The implementation is pure (no AppKit/I/O/disk/machine dependency), matches ADR-008 §2.4/§2.5 and the task packet, is fully unit-tested (27 new tests, all passing; full suite 660/0), keeps the app-launch path safe from folder identity via the existing `as? AppID` cast, preserves backward compatibility of `AppGridFocusIdentity`, respects the privacy redline, and leaves all frozen trees untouched. **PASS.**
