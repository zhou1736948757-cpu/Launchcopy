# Main Grid Capacity Foundation Worker

Date: 2026-10-17
Status: READY_FOR_MAIN_VERIFICATION — code/test inputs stable; no tests/builds executed; no PASS claim.

## Stable integration API

- `public struct MainGridCapacity: Codable, Equatable, Sendable` in AppGridUI: immutable `columns: Int`, `rows: Int`; failable `init(columns:rows:)`; `static let default` = 5×7; computed `itemsPerPage: Int`. Both dimensions must be in 3...8 before multiplication.
- App-layer `MainGridCapacityPersisting: Sendable`: `load() async -> MainGridCapacityLoadResult`; `save(_:recoveringCorruptPayload:) async -> MainGridCapacitySaveResult`.
- `MainGridCapacityLoadResult: Equatable, Sendable`: `.missing`, `.loaded(MainGridCapacity)`, `.corrupt`, `.protectedPayload`, `.unavailable`; `capacity` returns loaded value or `.default`.
- `MainGridCapacitySaveResult: Equatable, Sendable`: `.saved`, `.invalid`, `.protectedPayload`, `.recoveryRequired`, `.failed`.
- `actor FileMainGridCapacityStore`: nonthrowing `init(directory: URL)`; internal `init(io: any AppLibraryFileIO)` for deterministic I/O tests. The injected directory is the dedicated capacity directory, not its parent. File is `capacity.json`. No factory/global data access.
- V1 envelope: `{"schemaVersion":1,"capacity":{"columns":5,"rows":7}}` with exact known keys. Unknown/ambiguous/future envelopes remain protected, including during explicit recovery.
- Pure anchor API: `MainGridCapacityAnchorRelocation.relocate(previousEntries:currentEntries:currentPageIndex:selectedIdentity:from:to:) -> MainGridCapacityRelocation`; sequence arguments are `[TopLevelEntryIdentity]`, capacities are `MainGridCapacity`. Result exposes `pageIndex: Int`, `anchorIdentity: TopLevelEntryIdentity?`, `selectedIdentity: TopLevelEntryIdentity?`, `selectedPageIndex: Int?`, `selectedSlotIndex: Int?`. No query/focus mutation. Only an existing valid selection on the previous visible page becomes its anchor; a valid off-page selection is relocated separately. No selection is manufactured. Fallback: first surviving old-page identity, then nearest surviving old index from that page's start (lower-index tie), then a clamped current-sequence index if all old identities vanished. Empty current sequence returns page0 and nil identities.

## Scope

Only the five assigned new files. Preserve existing dirty work. Main owns coordinator, integration and all executions. Human waived Chief workflow; no subagents invoked.

## Implementation delivered

- The domain validates both dimensions before any capacity multiplication. Decoding invokes the same failable initializer, preserving the invariant against negative, out-of-range, overflow-sized and wrong-type input. Same-product shapes remain distinct values.
- Pure identity relocation computes locations from the current visible sequence. It neither changes canonical workspace order nor invents focus/catalog revisions. Hostile page indices clamp before multiplication. App and folder identities use the existing neutral type. The owner must still preserve query/IME/deferred-focus state and perform its accepted layout transaction.
- The actor has no MainActor/AppKit dependency and no suspension within a read/write transaction. Missing inspection is read-only, including a nonexistent directory. Only save may create its own supplied directory through the reused primitive.
- V1 persistence strictly admits the known envelope/body key sets. Bounded lexical inspection precedes typed body decoding, recognizes escaped object-key equivalents, and protects duplicate keys, unknown keys and all headers other than the exact integer token `1`. A future/overflow header is protected even with a malformed/truncated body. Oversized (over 8 KiB) and non-UTF8 content is protected. Missing/unparseable supported data is corrupt; loading never repairs it.
- Save rereads storage, applies protection/recovery policy to those actual bytes, then passes the exact baseline to atomic replacement. Read errors and replacement failures return `.failed`. Saved means the replacement primitive returned successfully after its file/directory flush work; no in-memory success fallback or equal-content early return exists.
- Corrupt recovery is explicit. Unknown/ambiguous/future payloads cannot be recovered through this API. A fresh protected payload supersedes an earlier loaded state. Failed post-replacement flush is treated as indeterminate failure; equal-value retry still performs the write/flush.

## Exact changed files

All five files are new; no preexisting file was edited:

1. `Sources/AppGridUI/MainGridCapacity.swift`
2. `Sources/PagingPrototypeApp/MainGridCapacityStore.swift`
3. `Tests/AppGridUITests/MainGridCapacityTests.swift`
4. `Tests/PagingUITests/MainGridCapacityStoreTests.swift`
5. `Workflow/results/MAIN_GRID_CAPACITY_FOUNDATION_WORKER.md`

Existing dirty workspace changes were preserved. No coordinator, settings, owner, appearance, workspace, package or workflow-state files were changed by this Worker.

## Authored verification inputs

23 XCTest methods, **not executed by this Worker**:

- 10 domain/relocation methods: default/endpoints, all 36 supported-pair Codable round trips, extreme invalid inputs/decodes, same-product distinct shapes, selected folder anchor, larger/smaller capacity, first surviving old-page anchor, off-page selection, disappeared selection/page, partial last page, hostile page indices, empty/fully replaced presentations and absence of invented focus.
- 13 store methods: missing/no creation/default, actual isolated file reload and sibling-byte preservation/private permissions, future/malformed/overflow/unknown/escaped-duplicate preservation, oversized/non-UTF8 protection, explicit corrupt repair, escaped supported keys, fresh protection before save, deterministic read/write failures, nondirectory/symlink refusal, expected-byte mismatch during replacement, ancestor namespace swap, cooperative lock refusal/retry, indeterminate flush/equal-value retry.
- Filesystem tests allocate disposable uniquely named temporary roots and canonicalize fixture paths with `realpath` to satisfy no-follow traversal. They never access formal capacity/workspace/appearance state. These test bodies have not run yet.
- Read-only inspection confirmed the existing SwiftPM target/test conventions and the reused I/O protocol. `git status --short` for the five assigned paths reports only those new files. A scoped `git diff --check` exited 0, but these files are untracked so that command is not a substantive whitespace/compilation check.
- Executed tests: **0**. Builds: **0**. UI/process actions: **0**. Native restart verification: **not performed**. Independent review: **pending Main**.

## Atomicity, isolation and honest limits

- Reuse is intentional: `any AppLibraryFileIO` / `LocalAppLibraryFileIO` already implements pinned no-follow directory descriptors, private temporary files, nonblocking advisory lock admission, under-lock expected-byte comparison, atomic rename and file/directory fsync. No duplicate POSIX implementation or modification to that primitive was introduced.
- Its lock filename remains `.library.lock`, and temporary names retain `.library-write-`; both are scoped to the dedicated capacity directory supplied by Main, so no library preference state is shared. Main must pass a dedicated directory rather than the existing library directory. Fixed target is `capacity.json`.
- The primitive's internal compare reads up to its existing 1 MiB limit. Capacity admission reads at most 8 KiB plus one sentinel byte and protects an oversized target before commit. A changed/larger target cannot match the admitted exact-byte baseline.
- This is a cooperative-writer policy. Lock contention, unsupported advisory locking or unsupported replacement/flush operations return `.failed`; they do not fall back to an unlocked write. Namespace/target changes observed before replacement are refused. Atomic compare-and-swap against arbitrary writers ignoring the lock is **not** guaranteed; a last-moment uncooperative write can race rename. No claim of universal cross-process isolation or power-loss recovery is made.
- An I/O failure after rename can leave the new bytes visible while returning `.failed`; only a subsequent actual successful retry acknowledges persistence. The Main coordinator owns accepted-write drain/receipts and user-facing failure handling.
- `.invalid` is retained as the exact agreed result API and defended at save admission, though ordinary safe construction/decoding cannot produce an invalid immutable capacity. No unsafe invalid-value fabrication is used in tests.
- Foundation integer decoding supplies value-level integer validation; schema-version admission additionally requires the exact lexical token `1`. The lexical inspection is a conservative protection preflight, not an independent JSON validity parser. Successful Foundation parsing and invariant-checked typed decoding are still required to load a value.
- Native factory/profile selection, owner epochs/Quit drain, integration layout/readability/input state and native restart remain Main's scope. File reload tests establish persistence only after Main runs them; they do not establish native restart, UI or physical interaction acceptance.

## Handoff

The four Swift code/test files are stable for Main's serialized focused suite and independent source review. Main may use the stable protocol/result enums immediately. Suggested focused selection: `MainGridCapacityTests|MainGridCapacityStoreTests`, plus Main's coordinator/geometry/readability tests. Only Main executes tests/builds. Any compilation/test failures should be retained as actual evidence and returned for a bounded repair; this Worker does not self-certify PASS.
