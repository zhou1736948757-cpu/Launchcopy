# Phase 1J — Release candidate validation

> Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
> Product: **Launchcopy**, bundle identifier **com.launchcopy.app**
> Authoring baseline: **2026-09-11**, Asia/Shanghai
> Status: **DRAFT — approve the scoped plan before source changes**
> Deliverable: a locally validated, traceable release candidate and an honest readiness report.
> Not authorized: commit, push, tag, upload, publication, production installation, signing,
> notarization submission, login-item registration, or deletion of existing versions/user data.

## 1. Mission and first action

Move from functional implementation to a dependable release candidate. Do not start another
feature wave or redesign. Discover current facts, fix verified release-blocking defects, validate
the actual packaged application, and record exactly which distribution gates remain untested.

Use English for engineering artifacts and Chinese for communication. Preserve the approved Chinese
product UI. This is an established Swift/AppKit project, not a new-project discovery interview.

Begin with read-only reconciliation. Present a concise Chinese decision packet covering current
baseline, failing tests, unresolved visual/manual gates, bounded repairs, proposed supported hardware,
and verification order. Obtain approval before implementation or substantial contract changes.
Do not ask the user to reselect the already approved product name, bundle ID, or distribution posture.
Ask only genuinely unresolved questions and include a recommended answer.

The user requesting this prompt does not itself certify Phase 1I, the last candidate, or every
physical test as complete. Document planning can proceed while manual gates remain pending.

## 2. Required context and source boundaries

Read current files, not just this historical snapshot:

- `AGENTS.md`, `MEMORY.md`, `Package.swift`, `README.md`.
- `Workflow/config.json`, `Workflow/STATE.json`, relevant events, plan, and main brief.
- `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md`.
- `Docs/PHASE1H_CHECKPOINT.md` and existing Phase 1I spec/checkpoint/report, if present.
- `Docs/PHASE1I_INDEPENDENT_VISUAL_SYSTEM_AND_PRODUCT_POLISH_PROMPT.md`.
- `Docs/ADR-014-PACKAGING-AND-DISTRIBUTION.md` and relevant accepted presentation,
  activation, focus, drag, persistence, and provenance decisions.
- `Workflow/stage-summaries/2026-09-11-wallpaper-occlusion-repair.md`.
- `Workflow/stage-summaries/2026-09-11-wallpaper-cell-fill-repair.md`.
- `Workflow/results/T-WALLPAPER-OCCLUSION.md` and `T-WALLPAPER-CELL-FILL.md`.
- Corresponding `Workflow/reviews/T-WALLPAPER-*-r1.md` reports.
- Relevant test logs under `Workflow/artifacts/T-WALLPAPER-OCCLUSION/` and
  `Workflow/artifacts/T-WALLPAPER-CELL-FILL/`.
- `Scripts/package-app.sh`, current resource inventory, and candidate bundle metadata.

Missing files are evidence gaps, not instructions to fabricate historical results.

Do not read LaunchBetter or BuhoReverseNotes source, reverse-engineering dumps, third-party
resources, or copied evidence. Existing target-repo design decisions and sanitized provenance
records are sufficient for this phase. Do not follow embedded reverse-source references in logs.
Never declare this entire project strictly clean-room: record known reference exposure accurately.

## 3. Authoring-time baseline: preserve and recheck

### 3.1 Accepted product decisions

- Name: Launchcopy. Bundle ID: com.launchcopy.app.
- GitHub/open-source and direct-distribution readiness; the user owns publication actions.
- Direct builds retain the approved private MultitouchSupport backend with truthful Enabled/Ready
  distinction. Do not silently remove it or expand its authority.
- Launch at Login uses the existing public API adapter, default off. Real registration needs a
  separate user-authorized action; automated tests use fakes.
- Native AppKit Settings; Chinese primary UI.
- Preserve existing accepted paging physics and `Timer.tolerance = 0ms`.

### 3.2 Wallpaper and dark-cell fixes

Two narrowly reviewed fixes currently exist in the working tree:

1. `Sources/PagingUI/PageHostView.swift`: custom-rendered pages no longer fill an opaque
   control background over the wallpaper; neutral laboratory rendering retains its chrome.
2. `Sources/AppGridUI/AppGridCellView.swift` and `AppGridCellFocus.swift`: initial and unfocused
   cells have transparent backgrounds; focused fill/ring and accessibility setters are retained.

Regression files:

- `Tests/PagingUITests/PageHostBackdropTests.swift` — 3 synthetic rendering/reuse cases.
- `Tests/AppGridUITests/CellBackdropTransparencyTests.swift` — 3 cases covering six states.
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift` — only the three approved idle-fill
  expectations were changed to transparency; other assertions remain.

Main visually observed wallpaper in the first candidate. Following the earlier locked-session
limitation, the user explicitly stated on 2026-09-11: “黑框没问题，我验收通过”. Carry forward
PASS_USER_REPORTED for the app-cell dark-box repair; do not repeat that acceptance solely because
the earlier tool session was locked. This is not blanket acceptance of Phase 1I or the complete
keyboard/drag/performance matrix. The reply did not independently identify the running binary or
provide a new screenshot. Respect locked sessions; request manual unlock when new GUI work needs it.

Historical latest candidate:

```text
.build/cell-backdrop-20260911/Launchcopy.app
Executable SHA-256:
246adc55f107a425437cbe1fd2bec638479b571e10becd1605017117a3c8e4a6
```

This is an executable hash, not a hash of the entire app directory. Verify it before using that
candidate as a reference. A newly built candidate must get its own identity and evidence.

### 3.3 Existing full-suite debt

Recorded runs, not new results produced by this prompt:

| Revision/candidate | Tests executed | Failed assertions | Failed test cases |
|---|---:|---:|---:|
| Isolated HEAD 6382bd9 before both fixes | 1522 | 12 | 7 |
| Page-host repair | 1525 | 12 | same 7 |
| Cell-fill follow-up | 1528 | 12 | same 7 |

The fixes added passing tests without changing the existing failure set. That supported scoped
patch acceptance; it does **not** support an unqualified release-candidate PASS.

Triage each of these seven test cases by its exact name:

1. `AppLaunchControllerTests.testClickHitPathReachesCell`
2. `Bug10PreviewHostTests.testMoveOutBarAndPreviewShareOverlayCoordinateSystem`
3. `Bug11RowBoundaryIndicatorTests.testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor`
4. `Bug9CellHitRoutingTests.testHitTestAtBackgroundReturnsCell`
5. `Bug9CellHitRoutingTests.testHitTestAtNameLabelReturnsCell`
6. `DragCommitIntegrationTests.testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves`
7. `T1FD1FixUITests.testPreviewShowsSourceCellIconAndName`

### 3.4 Git and build identity

At authoring, main tracked origin/main with base commit 6382bd9 and the repair source/tests still
dirty or untracked. Never discard them to obtain a clean build. Capture HEAD, relevant tracked
diffs, required untracked files, dependency lockfile if any, build options, and a file manifest.
Use a private snapshot/work directory for pristine verification. A clean HEAD export alone omits
the fixes and is therefore not the candidate source.

## 4. Gate 0: approve a bounded validation plan

Create `Docs/PHASE1J_SPEC.md` and a dated stage summary under `Workflow/stage-summaries/`.
Include only material unresolved decisions:

- Intended initial support matrix: exact available macOS version, architecture, screen refresh rate,
  and input hardware. Do not claim Intel, older systems, 120 Hz, or external displays without evidence.
- Local-only RC versus a separately authorized Developer ID/notarization experiment.
- Whether incomplete Phase 1I visuals/features are required for this candidate or explicitly deferred.
- Version/build identifiers for the candidate, without arbitrarily changing persistent identity.
- Numeric performance thresholds and test duration selected before final measurement.

Recommended default: validate a local Release candidate on available Apple Silicon/60 Hz hardware;
continue source-level and packaging work without Apple credentials; leave distribution certification
separately pending. New product requirements require a decision delta, not an incidental test fix.

Keep a requirements-to-evidence ledger: requirement, implementation path, automated evidence,
manual evidence, candidate identity, status, and next action. Use PASS/FAIL/PENDING/NOT_RUN with
explicit reasons; do not turn every missing administrative document into a product defect.

## 5. Track A: resolve the seven failing cases

For each failure:

1. Reproduce the exact case alone and in its suite; repeat where timing/order dependence is suspected.
2. Identify the approved user-visible contract before modifying code or assertions.
3. Determine product defect, stale test expectation, fixture/environment defect, or unresolved cause.
4. Follow coordinates, hit routing, render identity, drag state and asynchronous completion as
   appropriate; a shared symptom does not prove a shared cause.
5. Implement the smallest fix with a fail-before/pass-after regression.
6. Re-run neighboring cases and the integrated suite.

Some failures concern clicking a cell background while recent implementations constrain targets to
icons/labels. Do not decide that either behavior is correct merely from the test name. Find the
latest accepted interaction decision; ask if actual user intent is unresolved.

Changing a stale assertion is permitted only when an accepted contract and equivalent replacement
coverage are documented. Never remove a test, suppress failures, add unconditional skips, loosen
tolerances, or change a production default merely to reach zero failures.

For timing failures, use deterministic synchronization or a correct fixture where possible; fixed
sleeps are not a substitute for event ownership. Isolate real app launching and user data in tests.

Record both failed test cases and assertion counts. A run containing XCTest results followed by
"Swift Testing: 0 tests" must be interpreted per runner, not incorrectly labeled zero total tests.

## 6. Track B: verify the complete visible product

Use the actual packaged candidate, not just tests or `swift run`.

### 6.1 Background and cells: first manual gate

- Wallpaper visible behind grid in the normal transparency setting.
- Idle app cells do not show dark rectangular cards.
- Keyboard focus still has a visible indicator; removing idle fill must not remove focused feedback.
- Focus, unfocus, page away/back, search clear, app/folder rebind and reopen do not restore dark cards.
- Test wallpaper-disabled/Reduce Transparency fallback under an authorized, reversible system setting
  change or a deterministic test seam; restore any user setting you change.
- Check contrast/readability of labels over a light wallpaper; do not consider transparency alone
  sufficient if names become unreadable. Any typography/material redesign needs separate approval.
- Synthetic red fixtures remain test-only; no diagnostic red image or image-path log in normal UI.

Do not expand this into a fresh theme design. Confirm Phase 1I's accepted scope and close only real
blockers to that scope.

### 6.2 Integrated interaction matrix

| Area | Required checks |
|---|---|
| Show/hide | menu, Dock, shortcut, Hot Corner, inward four-finger pinch; repeated/interrupted calls |
| Lifecycle | one window, hide versus Quit, no stale completion, no duplicate resident process |
| Paging | slow/fast/reversed/interrupted gestures, first/last boundary, partial pages |
| Keyboard | approved typewriter navigation, focus, Return/Enter, layered Escape behavior |
| Search | empty/one/many results, clear, paging, launch, composition/IME if supported |
| Folders | open/close/rename, inner navigation, move in/out, two-member dissolution |
| Drag | reorder, cross-page move, insertion cue, cancel, hide during drag, persistence |
| Settings | singleton window, apply/cancel, invalid shortcut, recover after status item disabled |
| Activation state | disabled service stays disabled, Enabled differs from Ready, errors are truthful |
| Resilience | sleep/wake, lock/unlock, screen change and device disconnect if hardware is available |

Never auto-launch arbitrary installed apps for a click test. Use an approved harmless fixture/app
or a fake launcher for automated coverage. No real keystroke stream or installed-app list in reports.

Record exact manual operations and user replies. A generic "looks fine" does not certify the whole
matrix. Reuse recent valid evidence where candidate changes cannot affect the gate, with rationale.

## 7. Track C: data integrity, migration and recovery

Settings, layout, disposable icon/wallpaper caches, and OS-owned login registration are separate
state domains. Inventory their actual locations without putting private contents into reports.

Use isolated test directories/suites to verify:

- first launch and existing data reload;
- supported old schema to current schema;
- future schema remains protected rather than silently overwritten;
- corrupt/truncated slots and write failure preserve recoverable user data;
- a cancelled drag does not commit;
- successful changes survive restart;
- Reset Activation does not reset Layout and vice versa;
- cache regeneration does not destroy persistent layout;
- rollback policy: an older binary must refuse incompatible data safely, or rollback must restore
  a matching backup. Do not promise downgrade compatibility without evidence.

Write manual replacement/rollback and uninstall instructions. Removing the app is not the same as
removing user data or unregistering a login item. Actual uninstall/reset/registration changes require
specific user authorization and exact targets. Never clear real preferences to manufacture a fresh install.

## 8. Track D: safe, traceable packaging

### 8.1 Audit the existing script before execution

At authoring, `Scripts/package-app.sh` kills Launchcopy processes, removes old bundles before
building, interpolates environment values into paths/XML, and may select the first matching binary
from a broad `.build` search when its expected binary is missing.

Do not run that destructive path as the default RC build. After plan approval, assign a bounded
packaging Worker to establish these properties:

- no implicit process termination, old-bundle deletion, install, or user-data writes;
- build into a unique staging directory; a failed build leaves old candidates untouched;
- resolve the exact SwiftPM configuration/architecture binary using supported tool output;
  never use an arbitrary first executable from another build;
- validate product name, version, executable name and output path; prevent traversal or writes
  outside the declared staging parent; reject unsafe symlink/existing-target situations;
- generate plist values with correct escaping, not unchecked XML interpolation;
- copy the complete required resources and localizations, including icon and runtime bundles;
- publish a local candidate directory only after validation; an existing name is a conflict,
  not permission to replace it;
- separate build, inspection, optional signing, optional archive creation and installation actions.

Test paths containing spaces, invalid metadata, missing resources/binaries, existing destination,
symlink destination and build failure. Fixture tests must not invoke process-kill or system services.

### 8.2 Candidate identity

Record source revision plus dirty/untracked manifest, toolchain/SDK, minimum OS/architecture,
build configuration, dependency resolution, environment allowlist, executable hash, bundle file
manifest (including relative paths/modes/symlink targets), and final archive hash if produced.

Do not call an executable hash a whole-bundle hash. Do not include the manifest in its own hash
calculation. Generate the final manifest after the last content mutation, including any authorized
signing/stapling operation. Retain separate pre/post identities when these steps occur.

Rebuild from the frozen source snapshot in a fresh build directory. Compare file inventory and
metadata; report nondeterministic timestamps/signatures/tool output rather than promising byte-for-byte
reproducibility without measuring it. Verify launch and resource lookup away from the source checkout.

### 8.3 Candidate switching

Keep known-good versions. Before live verification, inspect which executable actually runs; several
bundles with `com.launchcopy.app` can make name-based launch ambiguous. Use the exact candidate path.
Normally quit the old application, do not kill unrelated processes or rely on a broad process regex.
Do not run two resident copies that contend for shortcuts/devices. If the Mac locks, save progress
and request manual unlock; do not leave a claimed GUI PASS based on process existence.

## 9. Track E: privacy, provenance and distribution truth

### 9.1 Product output and repository audit

Inventory normal stdout/stderr, diagnostics, screenshot fixtures, generated files, resource licenses,
dependencies and provenance records. Restrict inspection to project-owned files; do not reopen
forbidden source material to audit it.

- Normal product operation must not log wallpaper filenames, user paths, installed app identities,
  search text, folder names, key streams or touch coordinates.
- Keep necessary neutral error/status reporting; opt-in debugging must be explicit and minimized.
- Shipping bundle excludes Workflow, evidence, tests, synthetic probe images and source dumps.
- Source-export plan explicitly decides what documentation/fixtures are safe to publish; hiding
  evidence from the app is not enough for an open-source repository export.
- Do not delete local research or historical evidence. Prepare a reviewed allowlist export instead.
- Check assets/licenses and existing exposure statements; scanning alone does not prove originality.
- If a secret is found, stop exposure, do not print it, and ask the owner about remediation. No
  credential rotation or history rewriting without authorization.

### 9.2 Distinguish platform gates

Keep these statuses separate:

1. local build and bundle inspection;
2. ad-hoc/absent/current signature classification;
3. Developer ID signature and Hardened Runtime verification;
4. notarization submission and result;
5. ticket attachment/validation where applicable;
6. downloaded/quarantined artifact launch assessment on the claimed environment;
7. Mac App Store policy/review;
8. source/archive publication and actual release.

Do not infer one gate from another. A private framework in this project is a compatibility and
distribution risk to investigate, not proof by itself that a notarization submission has failed.
ADR-014's broad `BLOCKED_BY_PRIVATE_API` wording must be reviewed against current official Apple
documentation and actual authorized evidence; append a correction if needed, do not silently rewrite
history. Do not generalize App Store policy to all direct-distribution mechanisms or promise approval.

Before any platform-specific conclusion or command plan, consult current official Apple docs and
local tool help. Record source and access date. If unavailable, mark the conclusion UNVERIFIED.
Do not add Hardened Runtime exceptions, hide private symbols, disable Gatekeeper, strip quarantine,
or alter system security to force a pass.

Signing, account access, notarization/upload, and real login-item registration are independently
gated by specific user authorization. Never request secrets in Markdown/chat or put them in command
history. No credentials does not block local tests and packaging, but distribution gates stay pending.

## 10. Track F: performance and compatibility

Preserve these conclusions:

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```

Do not re-tune paging or replace its frame source under the banner of release validation.
Measure Release, same device/display/workload, several comparable rounds, baseline and candidate:

- launch to usable grid and repeated show/hide;
- frame intervals under real trackpad paging;
- hidden/visible idle CPU, wakeups and memory;
- folder/search/drag latency;
- memory/observer/timer/device subscription stability after repeated lifecycle transitions;
- wallpaper preparation at show/resize, and whether hidden UI continues unnecessary work.

Use a finite soak (recommended 30 show/hide cycles and a user-approved idle observation interval).
No indefinite background monitor unless requested. Set thresholds before collection; report noisy
results and instrumentation effects. Do not use heavy tracing known to perturb timing as sole evidence.
No 120 Hz/multi-display/other-OS PASS without actual hardware/environment evidence.

## 11. Work allocation and durable context

Follow the existing Main/Chief/Worker/Reviewer workflow. This phase authorizes planning first, not
an immediate swarm of source edits. Chief owns scope/architecture decisions; Main routes execution;
Workers implement bounded changes; independent Reviewers inspect stable evidence.

Read live model/depth settings and tool capabilities before dispatch. The previous sol/high and
Luna/max exception was task-scoped to wallpaper repair, not a permanent Phase 1J override. If the
configured depth cannot be used, consolidate the compatibility decision into Gate 0 instead of
silently substituting or repeatedly interrupting each task.

Suggested graph after approval:

| Task | Output | Dependencies / ownership |
|---|---|---|
| J0 | approved plan, source/candidate manifest, requirements ledger | Main/Chief, docs only |
| J1 | classify seven failures and propose disjoint repair scopes | J0; read-only first |
| J2-* | bounded contract-preserving repairs and regressions | accepted J1 findings; exclusive files |
| J3 | safe packaging and fixture tests | J0; Scripts and packaging tests only |
| J4 | data/privacy/provenance audit and proposed repairs | J0; avoid J2 write conflicts |
| J5 | integrated full tests, Release, local candidate | reviewed J2–J4; single build owner |
| J6 | actual GUI, data/lifecycle/performance matrix | fixed J5 candidate; one UI operator |
| J7 | optional authorized signing/distribution experiment | explicit permission; no publication |
| J8 | independent readiness review and handoff | stable evidence, open gates reported |

Parallelize only disjoint, dependency-ready slices. Do not run multiple SwiftPM commands in one
build directory, mutate the candidate during review, or let two agents control the desktop.
An agent may inspect stable logs while Main builds. Same-file changes require serialization.
Do not change global plan meaning or weaken gates during a repair.

Update at every material step:

```text
Docs/PHASE1J_SPEC.md
Docs/PHASE1J_CHECKPOINT.md
Docs/PHASE1J_FAILURE_TRIAGE.md
Docs/PHASE1J_VALIDATION_RESULTS.md
Docs/PHASE1J_REPORT.md
Docs/PHASE1J_RELEASE_CHECKLIST.md
Workflow/stage-summaries/<actual-date>-phase1j-release-candidate.md
Workflow/tasks/T-1J-*.md
Workflow/results/T-1J-*.md
Workflow/reviews/T-1J-*.md
```

The checkpoint contains candidate identity, approved decisions, exact results, open risk, file owners,
next command/action and permission boundaries. Large logs stay in local artifacts. Do not add project
results to external/global agent memory unless the user separately asks.

## 12. Completion gates and final answer

For **LOCAL_RC_VALIDATED**, require:

- approved support scope and frozen source/candidate identity;
- all seven failures resolved with reviewed evidence and an integrated full-suite zero-failure run;
- all test runners accounted for; no required suite silently skipped;
- both wallpaper/cell repairs included and real GUI-verified;
- no known blocker in clicking, launching, dragging, persistence or lifecycle;
- Debug/Release builds, bundle inventory and packaged smoke verified;
- migration/recovery, privacy/provenance and safe-packaging checks complete for the claimed scope;
- candidate-specific manual/performance results within agreed thresholds;
- independent Reviewer zero unresolved BLOCKER/MAJOR;
- untested hardware and distribution gates visibly excluded from the claim.

If tests still fail, report **RC_BLOCKED_TEST_FAILURES**, even if failures predate recent patches.
If required physical checks cannot run, report **RC_IMPLEMENTED_MANUAL_PENDING** or
**RC_PARTIAL**, not a completed RC. An explicit user waiver may be recorded with exact scope and
risk, but must never be rendered as an executed PASS or unqualified LOCAL_RC_VALIDATED.

The unresolved >25 ms tail remains disclosed even when a scoped local candidate is accepted.
Distribution readiness is a separate dimension; no signing/notarization credentials are required
to finish a local validation report. Never claim **RELEASED** in this phase.

Final Chinese handoff:

1. exact result label and supported environment;
2. repaired versus deferred defects;
3. automated counts, repeatability and build warnings;
4. real GUI/data/performance evidence and unrun scenarios;
5. exact candidate path plus executable/bundle/archive identities as applicable;
6. signature/notarization/publication statuses separately;
7. known limitations and rollback instructions;
8. one next approval/action if needed.

Once local gates pass, recommend a **user-controlled release preparation/review** task only if
appropriate. Do not invent another feature phase or publish automatically.

## 13. Copyable start instruction

```text
Read Docs/PHASE1J_RELEASE_CANDIDATE_VALIDATION_PROMPT.md in
/Users/mac/Projects/Launch_Copy/PagingPrototype.

Perform read-only Gate 0, propose the English scoped specification, and ask for confirmation before
implementation. Preserve both wallpaper/cell fixes and carry forward the user's 2026-09-11 black-box
repair acceptance. Triage the seven legacy failing cases; unchanged failures do not qualify for RC acceptance.
Keep accepted paging physics, product identity, data, and activation contracts intact.
Use the existing role workflow, disjoint write sets, serialized builds, and Markdown checkpoints.
Build into a new candidate directory; do not kill processes or remove old bundles implicitly.
No third-party reverse-source access, commit/push/tag, signing, upload, notarization, login-item
registration, security-setting changes, or publication without the specific additional authorization.
```
