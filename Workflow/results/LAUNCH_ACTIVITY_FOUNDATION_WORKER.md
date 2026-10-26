# Launch Activity Foundation Worker

Date: 2026-10-18
Status: IMPLEMENTATION_COMPLETE_AWAITING_MAIN_VERIFICATION

## Scope and source context

Read the project AGENTS.md, approved Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md including its appended approval, Workflow/stage-summaries/2026-10-18-library-launch-activity.md, and the existing reference/projection/store/test conventions. This is the bounded Swift/macOS foundation assignment. Existing dirty work was preserved. No plan, stage summary, profile location, owner, coordinator, launch executor, UI, localization, package configuration, Library schema or workspace schema was changed by this worker.

## Exact changed files

- New `Sources/AppGridUI/AppLibraryDomain/LaunchActivity.swift`.
- New `Sources/PagingPrototypeApp/LaunchActivityStore.swift`.
- New `Tests/AppGridUITests/LaunchActivityTests.swift`.
- New `Tests/PagingUITests/LaunchActivityStoreTests.swift`.
- New `Workflow/results/LAUNCH_ACTIVITY_FOUNDATION_WORKER.md` (this report).
- `Sources/PagingPrototypeApp/AppLibraryStore.swift`: removed only `private` from `static hasDuplicateObjectKeys(_:)` and `static rootVersionTokens(_:)`, allowing module-local reuse of the unchanged strict JSON scanners. No other edit to that file.

## Delivered interfaces for Main

`public enum LaunchActivitySection: String, CaseIterable, Codable, Sendable` has `.recent` and `.frequent`.

`public struct LaunchActivityEntry: Codable, Equatable, Sendable` exposes mutable `lastLaunch: Date`, `dailyCounts: [Int: Int]`, and public `init(lastLaunch:dailyCounts:)`.

`public struct LaunchActivityDocument: Codable, Equatable, Sendable` exposes mutable `enabled: Bool`, immutable `salt: String`, mutable `entries: [String: LaunchActivityEntry]`, and these agreed signatures:

```swift
public init(enabled: Bool = false, salt: String = /* fresh valid UUID-pair hex */,
            entries: [String: LaunchActivityEntry] = [:])
public var isValid: Bool
public func key(for record: AppRecord) -> String
public mutating func record(_ record: AppRecord, at now: Date)
public mutating func prune(at now: Date)
public func rankedKeys(section: LaunchActivitySection, at now: Date) -> [String]
public func filtering(_ snapshot: AppLibrarySnapshot, section: LaunchActivitySection,
                      at now: Date) -> AppLibrarySnapshot
```

The storage module exposes internal `LaunchActivityLoadResult`, `LaunchActivitySaveResult`, `LaunchActivityPersisting: Sendable`, and `actor LaunchActivityFileStore` with precisely the agreed cases and method labels. The actor supports `init(fileURL:)`, `init(io: any AppLibraryFileIO)`, `static decode(_ data: Data)`, and the 1 MiB payload bound. Its concrete `save` defaults `recoveringCorruptPayload` to false; the protocol retains the explicit argument.

## Domain policies and concrete bounded choices

- Default consent is OFF. Admission requires enabled, structurally valid document and supported positive finite clock. Invalid admission changes nothing.
- Salt is exactly 64 lowercase hex characters from a UUID pair. Bundle keys reuse the exact canonical `PersistentAppReference` bundle identity; path-only/empty-bundle references become `path-hash:` plus SHA256 of UTF-8 `(salt + canonicalPath)`. No raw path or display name is stored.
- At most 256 identities and 30 UTC epoch-day buckets per identity. A nonempty entry includes its last-launch day; buckets must be within that day's previous 29 days, inclusive. Clock-relative expiry belongs to explicit `prune(at:)` and pure projection rather than structural validation.
- Daily counts saturate at 1,000,000. Positive Unix timestamps are bounded through 253,402,300,799 (last second of year 9999), keeping day conversion/arithmetic safe. Bundle identifiers are nonempty, at most 512 UTF-8 bytes, and contain no whitespace, controls or path separators.
- `prune(at:)` retains current day minus 29 through current day, excludes future-last-launch entries as a whole, and removes empty expired entries. Invalid clocks leave the document unchanged. Eviction prefers last-launch descending, then stable key ascending; over-cap direct values can be deterministically pruned, but fail `isValid` and cannot be recorded/saved/projected as valid first.
- `rankedKeys` returns the full eligible ordering, up to 256, before any display limit. Recent uses last-launch descending then stable key ascending; Frequent uses retained total descending, last-launch descending, then stable key ascending.
- `filtering(_:section:at:)` intersects with the already filtered base snapshot, deduplicates identities using the first matching base entry, and then applies Recent 12/Frequent 8. It preserves base counts, revision, aliases and categories. Missing/hidden/query-excluded entries cannot consume slots. It performs no I/O and returns immediately when no ranked identities exist.
- Each admitted `record` call means one accepted request. Distinct requests at identical timestamps count separately. Main's one-shot event/generation seam owns duplicate callback and stale admission rejection.

## Store and owner handoff

- Schema 1 envelope contains exactly `schemaVersion` and `document`. Nested document/entry shapes are strict; Int day keys must use canonical decimal spellings to reject post-decode key collisions.
- `load()` returns the exact decoded document: no clock reads, pruning, recovery, directory creation or writes. **Final Main clarification supersedes the earlier in-memory-pruning implementation:** the owner receives original loaded state, prunes with its injected clock, compares it with the original, and tracks the actual persistence receipt. Old/future records and original enabled/salt values are retained at the file-store boundary.
- Nonloaded `.document` values are fresh valid default-OFF empty documents; callers must not turn missing inspection into an automatic write.
- Main supplies the resolved profile-local Activity directory URL. The store has no formal-data fallback or autonomous path discovery. It reuses `LocalAppLibraryFileIO` without modifications: bounded read plus overflow byte, read without creation, descriptor-relative no-follow traversal, regular-file checks, private permissions, cooperative lock, compare before replacement, pinned-directory identity recheck, atomic replacement and fsync. The inherited `.library.lock`/temporary names remain inside the separate supplied Activity directory.
- Future versions, ambiguous/duplicate schemas and oversized payloads are protected even when recovery is requested. Corruption needs explicit recovery. Invalid documents are rejected before reading; read unavailability and replacement failure have separate result cases. Equal retries still attempt a real save receipt after an indeterminate replacement failure.
- Cooperative locking/observed comparisons do not promise atomic CAS against arbitrary uncooperative external writers; existing I/O limitations are unchanged.

## Test source delivered; execution deferred

21 domain test methods and 20 store test methods were authored. Coverage includes default-OFF, fresh salts, bundle move/name continuity, cross-salt path privacy, normalized and empty-bundle fallback, equal-time distinct requests, deterministic rankings/ties, exact UTC retention boundaries, old/future/invalid clocks, malformed dates/counts/keys, saturation, all 256 identities times 30 buckets at maximum count, oldest/tie eviction, visibility before 12/8 limits, dormant identities, aliases/query/categories/base counts, and duplicate catalog instances.

Storage coverage includes exact original old/future document loading for owner clock/receipt tracking, no-write/no-create load, private atomic round trip, maximum document round trip, explicit corruption recovery, future/duplicate/escaped/ambiguous headers, nested duplicate keys, strict unknown shapes/numeric day aliases, size and count caps, invalid-before-I/O, read/write failures, real retry receipts, symlink/FIFO/directory/ancestor rejection, cooperative locking, changed future target protection and ancestor-swap protection.

Only source inspection and repository read commands were used for verification. **No compiler, build, tests, UI, native candidate, formal/reference data, OS preferences, installation, signing, commit or process termination was run by this worker.** No runtime or test PASS is claimed. Main remains the sole focused/full build/test/native runner; independent review and acceptance are outstanding. No current blocker or interface deviation remains.
