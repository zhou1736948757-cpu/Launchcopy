# App Library Main foundation — independent source review

Date: 2026-10-15 (Asia/Tokyo)
Verdict: **SOURCE FAIL — four open findings.** The refreshed projection observer repair is sound at the source level and is not an open finding. This verdict concerns the first foundation wave only. App Library is not owner-wired or native/UI-complete; the Full Goal remains active.

## Authority and review boundary

The human authorized a read-only independent review, waived the formal workflow, and limited the sole write to this report. No implementation, test, workflow-state, or existing dirty-tree changes were made by this reviewer. Every shell invocation used RTK. No Swift command, build, test execution, app/process control, other-agent invocation, reference-product read, or evidence/log read was performed.

Contracts read: `Docs/APP_LIBRARY_SPEC.md` and `Docs/APP_LIBRARY_SLICE_PROPOSAL.md`. The approved specification incorporates the proposal; historical PROPOSED markers were not treated as another approval gate. Repository instructions and the supplied RTK rules were also read.

Reviewed implementation:

- `Sources/PagingPrototypeApp/AppLibraryStore.swift`
- `Sources/PagingPrototypeApp/AppLibraryStoreLocation.swift` (added to scope by the human)
- `Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift`
- `Sources/PagingPrototypeApp/AppLibraryProjectionController.swift`
- Library additions in `Sources/PagingPrototypeApp/UITestProfile.swift`
- `Sources/PagingPrototypeApp/WallpaperSourceInspection.swift`
- Source-inspector/diagnostic additions in `Sources/PagingPrototypeApp/WallpaperBackdropView.swift`
- Only source-inspector construction and diagnostic installation in `Sources/PagingPrototypeApp/AppDelegate.swift`: lines 564–573 and 2813–2823.

The corresponding store, store-location, preferences-coordinator, projection-controller and source-inspection test sources under `Tests/PagingUITests/` were read for coverage context, not executed. Domain-worker implementation/tests, localization work, reference products, and historical evidence were not reviewed.

## Open findings

### F1 — P1: duplicate preference fields remain writable decoder ambiguity

**Location:** `Sources/PagingPrototypeApp/AppLibraryStore.swift:145–160`, `167–198`; normal-write consequence at `124–135`.

**Evidence and trigger:** The token scanner checks duplicates only for the root `schemaVersion`. `JSONSerialization` then produces a dictionary, whose `Set(root.keys)` cannot retain duplicate-key multiplicity. `JSONDecoder` is independently used for the preferences value. For example, this payload has one valid v1 header but two conflicting, individually valid preference objects:

```json
{"schemaVersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:fixture":"music"}},"preferences":{"enabled":false,"categoryOverrides":{}}}
```

The source has no duplicate-`preferences` rejection before either decoder selects a value. The same limitation applies to conflicting duplicate fields inside preferences/override objects. This review does not depend on claiming which Foundation decoder chooses the first or last value on this particular runtime: the source permits decoder selection to resolve the ambiguity and subsequently treats the selected preferences as a writable v1 payload. A normal save can discard the other set of user overrides without an explicit recovery decision.

**Likely root cause:** Byte-preserving schema validation covers version declarations but not the rest of the persisted object whose duplicate keys also affect meaning.

**Recommended solution:** Reject conflicting duplicate object keys before converting the bytes into dictionaries/Codable values, including decoded escaped-key equivalents. Classify ambiguous payloads as protected/read-only; do not let `recoveringCorruptPayload: true` bypass that classification. Continue accepting a single escaped valid v1 header and harmless key-like string content.

**Affected scope / regression risk:** Store decoding and save admission. Avoid incorrectly treating keys in strings or separate objects as duplicates. Add byte-preservation cases for duplicate root preferences, duplicate enabled/override fields, and escaped equivalent keys. No such regression test was executed here.

**Confidence:** High in the missing source guard; exact runtime decoder selection was not measured.

### F2 — P1: payload/type checks are separated from the destructive replacement

**Location:** `Sources/PagingPrototypeApp/AppLibraryStore.swift:124–135`, `65–98`; read-side path handling at `36–46`.

**Evidence and trigger:** `save` inspects the target once through `load`, then encodes and calls `replaceAtomically`. The final `validateLocation()` before `rename` checks path/symlink spelling, not current target bytes, identity, schema, or regular-file type. If another writer replaces a loaded v1 target with a future-version payload while the temporary file is being written/fsynced, the final validation still passes and `rename` overwrites the future bytes. A corrupt, oversized, FIFO, or socket target introduced in that interval likewise does not receive the load-time protection. `O_NOFOLLOW` protects the final component of the individual open call; the full-path operations do not anchor ancestor directories against replacement between validation and use.

This is an external/filesystem-concurrency finding. The synchronous actor correctly prevents interleaving saves within this one store instance, but does not coordinate another store, process, or profile-directory mutation. No filesystem race was executed by this reviewer.

**Likely root cause:** The I/O interface separates `read` from unconditional `replaceAtomically` and carries no expected target identity/bytes or access coordination into the commit.

**Recommended solution:** Establish the supported exclusive-writer/coordination contract and make protected-target admission part of the commit transaction. Anchor directory traversal and temporary creation/replacement/cleanup to verified directory descriptors; reject detected target changes, symlink/type substitutions, and protected replacement payloads. Merely adding another full-path preflight does not close a check/use race. If arbitrary external writers are explicitly outside the supported contract, document that limitation rather than claiming unconditional byte protection.

**Affected scope / regression risk:** Local store I/O, target admission, and candidate-local path guarantees. Keep missing-load inspection directory-free, bounded reads, private permissions, and accepted-write ordering. Main should exercise controlled target/type and parent-directory swaps without touching production data.

**Confidence:** High in the unguarded replacement window; exploitation requires the stated concurrent filesystem change.

### F3 — P2: an older successful write is forgotten when the newest write fails

**Location:** `Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift:51–62`; drain result at `82–86`.

**Evidence and trigger:** Start with committed/disk preferences A; accept B and then C before B finishes. B saves successfully to disk, but its receipt reaches `token != generation` and returns before updating any persisted-state record. If C then fails before replacement, `latestSaveResult` becomes failure while `committed` remains A; the actual file remains B. The queue is drained and no receipt/state records that B is the last successful durable snapshot. A subsequent edit derived from `committed` can overwrite B's successfully accepted changes, and restart can expose a different state than the resident owner reports.

Suppressing publication of a superseded draft while a later draft is pending is correct. Discarding its successful persistence receipt leaves the terminal-failure path inconsistent.

**Likely root cause:** One generation gate controls both presentation publication and bookkeeping of actual successful writes.

**Recommended solution:** Retain the last successfully persisted preferences/generation independently of latest-request presentation. Define and implement terminal-failure reconciliation so a failed newest request cannot leave the owner treating A as its committed persistence baseline when B is on disk. Preserve the approved non-optimistic/failure presentation contract; do not label C saved or silently retry it. Add the B-success/C-failure sequence and a subsequent edit/reload check.

**Affected scope / regression risk:** Coordinator receipt tracking, failure state, and drafts derived after a failed batch. Preserve serial execution, latest-wins presentation, bounded drain, and non-cancellation of accepted writes. Existing source tests cover two successes and a single failure separately, not this combination.

**Confidence:** High; follows directly from the generation guard and assignment locations.

### F4 — P2: retry can report saved without completing a previously failed flush

**Location:** `Sources/PagingPrototypeApp/AppLibraryStore.swift:84–90`, `128`, `135–136`.

**Evidence and trigger:** Atomic replacement renames the new file before opening/fsyncing its directory. If directory open/fsync fails after the rename, `save` returns `.failed`, although reads can already observe the new preferences. Retrying the same draft calls `load`, sees equal preferences, and returns `.saved` at line 128 without retrying the failed directory flush. The accepted-write owner can then report `.persisted` on the basis of that result even though the operation that originally failed was never completed.

**Likely root cause:** Content equality is treated as a complete save receipt, including after an indeterminate post-replacement failure; the store tracks no outstanding flush state.

**Recommended solution:** Distinguish pre-replacement failure from post-replacement/flush failure, or otherwise ensure an equal-content retry still completes required persistence work before acknowledging success. Keep the no-op path safe for known completed writes without discarding an outstanding flush obligation. Test an injected I/O operation that installs bytes and then throws, followed by an identical retry, as well as the local commit phases.

**Affected scope / regression risk:** Store save receipts and Quit drain accuracy. The existing failing-I/O fixture throws before mutation, so its passing behavior would not establish this case. This finding concerns the source's own flush contract, not a claim of physical restart or power-loss acceptance.

**Confidence:** High in the control-flow gap; no actual filesystem flush failure was induced.

## Refreshed finding resolved at source level

The initial projection implementation notified `onChange` before setting `isProjecting`, and notified on completion only when a result had the expected revision. This was independently identified as actionable: observers could receive `[false]` rather than loading/terminal transitions.

The human subsequently reported a red observer regression (1 test / 1 failure) and Main's repair. This reviewer reread the refrozen implementation and updated regression source. Current `AppLibraryProjectionController.swift:54–60` starts work before publishing the update; `81–90` publishes the current open generation's terminal state even for nil/wrong-revision results, while keeping the snapshot non-actionable. `AppLibraryProjectionControllerTests.swift:92–103` now checks `[true, false]` for a wrong-revision result. **The identified observer defect is resolved in the refreshed source.** The nil-result path is covered by the same source condition, but no dedicated nil-result test was executed or observed here.

The earlier default-argument initializer was also reread after Main's concrete-class closure repair at lines 45–46. The store comment now correctly describes a single v1 header without incorrectly banning escaped valid key spellings. These are not open findings in this verdict.

## Sound source properties and limits

- The store actor's synchronous load/save bodies contain no suspension point. Coordinator predecessor tasks serialize accepted saves across async seams. Invalidation suppresses UI callbacks without cancelling accepted writes.
- Missing-load inspection opens/reads without creating directories. Reads are bounded to 1 MiB plus one distinguishing byte, check the opened descriptor is regular, and use nonblocking/no-follow flags. Existing static symlinks and special-file descriptors are rejected. These guards do not close F2's concurrent replacement window, and special files are checked after opening the descriptor rather than before all possible device-open effects.
- Detected future, version-ambiguous, and oversized payloads are refused even with recovery requested. Corrupt payloads require explicit recovery. No load path repairs bytes. F1 limits the completeness of ambiguity detection.
- Drain uses a monotonic deadline and receipt polling instead of awaiting an uncooperative writer in a structured losing task. Timeout preserves ownership of the accepted write. This is a source-level bounded waiting design subject to actor scheduling, not measured wall-clock responsiveness or integrated Quit acceptance.
- The refreshed projection controller holds at most one running task and one replaceable pending request. Closed `update` launches nothing; update clears stale snapshots; generation/open/revision checks prevent stale publication; close retains worker ownership through cancellation so reopen cannot create a second concurrent worker. Default projection executes in a detached utility task with cancellation forwarding. It does not preempt the synchronous domain projection mid-computation, and domain algorithm correctness/performance is outside this review.
- `AppLibraryStoreLocation.resolve` is pure and returns nil for an unresolved requested test profile; a resolved profile routes to its Library directory. The new profile directory is validated with the other output directories, and `.library` receives the existing candidate/profile namespace. These additions create no storage during resolution. Actual startup rejection, store construction and production fallback behavior at the future owner call site remain unwired/unreviewed.
- Source inspection exposes only kind/optional flags, follows the wallpaper target via metadata lookup without reading source content, and skips Foundation cloud resource keys for special files/directories. Both image and inspection completions are host/generation-gated. Metadata lookup can still block or involve a filesystem/provider; its result is descriptive and must not be used as proof of safe/nonblocking rendering.
- AppDelegate installs the background source inspector only inside the resolved `uiTestProfile` branch, and accessibility diagnostic help is guarded by that same condition. The default production controller has a nil source inspector. This establishes **no additional source-inspection I/O and no diagnostic accessibility mutation on the reviewed production construction path**, not a measured claim of absolutely zero CPU cost or overall wallpaper acceptance. Diagnostic inspector jobs themselves are not cancelled/coalesced; generation filtering suppresses stale publication, not already queued filesystem work. Keep that limitation explicit for repeated-refresh or stalled-provider profile workloads.

## Verification boundary and next action

This reviewer executed **zero tests** and inspected **zero build/test/runtime evidence logs**. Initially the test files were authored but unrun. During review the human reported an initial compile failure with no tests, its initializer repair, a focused r2 result of 107 tests / 0 failures, a serial full-suite run in progress, and then the observer red regression and repair. Those are attributed Main reports, not independently verified results. The reported 107/0 predates the latest observer repair and cannot certify this final refrozen source. No final full-suite outcome or post-repair green result was independently established here.

Before a source PASS, Main should disposition/repair F1–F4 and provide a fresh frozen review baseline with focused regression coverage. Recommendations here authorize no implementation edits by this reviewer. Native Library navigation, enable/settings/category controls, source-generation wiring, shared action validation, actual Quit integration, startup rejection, GUI/accessibility, physical restart/durability and performance acceptance remain future gates. Their absence in this intentionally unwired wave is not presented as another implementation finding or as completion. The Full Goal remains active.

## Reviewed source fingerprints

SHA-256 values after the explicitly requested refreshes (test sources may still change under Main ownership):

| File under Sources/PagingPrototypeApp | SHA-256 |
| --- | --- |
| AppLibraryStore.swift | `393e507cf2a7306270256eda0e3d46b4c5ba7f69ac15ac8ee12d991cc8570904` |
| AppLibraryStoreLocation.swift | `27358099b471e7cdbbda1c3c3061fd64937ad7769af5b2b2e74d795436943bbe` |
| AppLibraryPreferencesCoordinator.swift | `fbf99c14759f736177960697ab9c663cf3e8f6c74033b25f541821e3103496ff` |
| AppLibraryProjectionController.swift | `0ea791453aa1c6c6907071c83dc940cfef8e6ff78e4f78451262ac120a4a2309` |
| UITestProfile.swift | `cfda5a9ac39d21ef64bc866feb5a4604b455de6adbc6bab66e0c610492d0687d` |
| WallpaperSourceInspection.swift | `818f881820a6565ec260c474df534f8332fb0111c2d4646bac7e4c022a1f1887` |
| WallpaperBackdropView.swift | `4261f9b357a976a2fd18c7b7bdbea65beb41eeaa7de4891f8cb1d53ae9d656f7` |
| AppDelegate.swift (whole-file fingerprint; only scoped additions reviewed) | `af727372bf3feb4c97a36e3d2e57cf4b38dfde76913362b23ac9898757845d81` |
