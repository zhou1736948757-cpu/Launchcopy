# Architecture and maintainability optimization — first bounded wave

Date: 2026-10-20. Authorization: user requests a whole-code perspective and incremental optimization after checks. Existing SwiftPM/AppKit launcher; not a new product or behavior redesign.

## Problem / outcomes
The independent launcher has accumulated feature composition and diagnostic code across 217 Swift source files (~45.8k lines). Assess coherence, evolvability/buildability, reusable boundaries, lifecycle safety and testability, then implement a small set of evidence-backed optimizations. Preserve accepted interaction/appearance and durable data. A whole-repository inventory plus targeted deep review is not an exhaustive proof of correctness.

## Scope / non-goals
Review all production modules through explicit coverage assignments, dependency inventory and prioritized deep inspections. Main owns app/UI/composition/build scripts and integration. Sidecar A audits Core/UI/Grid domains. Sidecar B audits catalog/icon/localization/telemetry and app persistence/service coordinators. Initial auditors may write only their assigned review Markdown; no concurrent SwiftPM/UI work. Max three agents including Main, user-bypassed historical Chef machinery; Main serializes all tests/builds. Later bounded disjoint workers or independent reviewers replace completed agents, never exceed the ceiling.

Do not rewrite the app, change feature defaults, alter paging physics/layout/input semantics, migrate disk schemas, replace the toolchain, add dependencies, or generalize unrelated stores solely because code looks similar. No claim that previous hitch/flicker is physically accepted; that gate remains USER_RETEST_PENDING and may proceed separately. No formal data, reverse-reference source/assets, install/sign/publish/Git mutations/process signals/private screenshot files.

## Requirements / decisions
- Preserve the existing separation: pure domain state; AppKit adapters/presentation; explicit composition and isolated test profiles.
- Prioritize correctness hazards and demonstrably duplicated policies over cosmetic style. Every implemented change needs an owner, evidence, bounded scope and regression/structural acceptance checks.
- Use mechanical extraction where existing types are independent; keep privacy/diagnostic gates intact and avoid widening access just to move code. Do not confuse file splitting with full architectural decoupling.
- Shared helpers must represent the same contract and have at least two real consumers or a clear domain boundary. Preserve generation/lifecycle cancellation, source identity and accepted-write/quit protections.
- Avoid hot-path allocations/work and asynchronous ownership regressions, but make no runtime-performance claim without matched measurements.
- Preserve unrelated dirty work. Save a per-file hash baseline and exact stage deltas; no reset/clean/commit.

## Acceptance / delivery
Deliver a prioritized architecture report covering inventory, dependency boundaries, reviewed/deferred areas, risks, implemented changes, reusable seams and a staged backlog. Before coding, record the selected bounded changes and rationale in this spec/stage summary. Verify new behavior with focused tests or exact mechanical equivalence where appropriate, full nonzero test suite, Debug/Release/package and diff checks on frozen inputs. Independent review remains bounded source evidence. Native launch/visual/physical tests are distinct; do not reassign old acceptance to a new binary. Keep the latest runnable candidate identified and only replace it through normal owned-instance Quit when needed.

## Maintenance and open questions
AppDelegate is 5,255 lines with embedded window/input/diagnostic types; inspect safe extraction before larger coordinator redesign. Storage coordinators have different receipt/recovery semantics: audit before introducing a generic abstraction. Quantify baseline size/dependencies, do not optimize by file count alone. Broader feature parity and physical smoothness are not completion conditions falsely closed by this review wave.

## 2026-10-20 explicit feedback and selected first wave
User reports the FIRST Library entry still hitches and explicitly requests removal of the search blue frame. This is a failed cold-entry physical gate on bc701, not full physical acceptance; return flicker was not specifically answered. Prior wide-remnant correction remains historically accepted, but outline styling is now superseded by user design choice.

Selected bounded changes:
1. Main and Library search controls suppress both native control/cell outlines. Remove the custom Library focus decoration, its state/layout/key-event maintenance and redundant focus-only observers. Keep native caret/selection/IME/editor/AX identity, normal editing ownership notifications, and other controls' focus policies. Share a small same-contract focus policy across these two real consumers.
2. Prepare at most one EMPTY detached Library view shell during a deferred idle opportunity only after feature opt-in/readiness; no catalog projection, history capture, icon request or stale snapshot precomputation. Reuse that shell on entry and reset/detach on close before retention; no live owner.view while closed, no focus/AX/action ownership while prepared. Cancel queued preparation on entry/disable/teardown; disabled feature retains none. Apply current language/activity/bounds before mounting, reset layer presentation, and retain synchronous fallback if preparation is not ready. This moves construction off the first scroll event when possible; it does not prove material/compositor cold cost or physical hitch elimination.
3. Extract shared horizontal Library geometry used by actual layout and pre-layout icon admission, preserving exact420/600 thresholds and existing frames. Add boundary/mode tests so future visual changes cannot silently diverge from work admission.
4. Mechanically move independent window-input/diagnostic definitions out of AppDelegate into LauncherWindowInput.swift without changing their bytes, access levels, gates, sinks or event order. Verify moved-block hash/round-trip, existing routing regressions and full build. This improves navigation/cohesion but is not a completed coordinator decomposition or runtime optimization.

Avoid further generic store/core rewrites this wave. Larger recommendations belong in the prioritized report. All automatic/native/physical evidence remains separate; refreshed physical cold/repeat entry and no-blue-frame checks required on new candidate.

## Additional correctness priorities selected from independent audits
Domain audit F1/F3 reveal existing contract mismatches: a count-valid encoded layout may exceed its own1MiB decode cap, and higher-version JSON is recognized only after decoding all v1 fields. Repair these narrowly: check final encoded envelope bytes before IO, and inspect a minimal integer version header before v1 payload decoding. Keep v1 encoded bytes/checksum/limits/schema/recovery policy unchanged; future payloads remain protected, not migrated. Add codec and memory-journal preservation tests. Domain reset/initialization overlap and Core gesture reentrancy are larger separate changes and remain explicit high-priority backlog, not silently accepted.
Services audit F1 identifies queued activity Clear/OFF documents depending on a weak writer lifetime after owner invalidation/release. Assign only that finite accepted-write retention/handoff correction and injected-gate regressions to the disjoint services worker. Keep consent/coalescing/schema/late-callback policy unchanged. JSON inspection extraction, icon incarnation and synchronized diagnostics are deferred to avoid unrelated churn.
