# App Library Main foundation — independent source re-review R2

Date: 2026-10-15 (Asia/Tokyo)
Verdict: **SOURCE PASS for the bounded F1–F4 repair, under the documented cooperating-writer contract.** All four original findings are resolved at the source level. No new blocking finding was identified in this repair scope. This is not test/build/runtime certification, native Library availability, physical/model parity acceptance, or Full Goal completion.

## Scope, authority and attribution correction

This is the requested read-only re-review of R1 findings F1–F4. The only new write by this reviewer is `Workflow/results/APP_LIBRARY_MAIN_FOUNDATION_REVIEW_R2.md`. R1 was preserved. No implementation/test edits, Swift execution, builds, process control, other-agent operations, production-data writes, or evidence/log reads were performed. All shell invocations used RTK.

Reread source: `AppLibraryStore.swift`, `AppLibraryPreferencesCoordinator.swift`, and their corresponding `Tests/PagingUITests/` test sources. Reread `Docs/APP_LIBRARY_SPEC.md`, including its filesystem-coordination and receipt clarification. The approved proposal was already read in R1. Previously reviewed projection/profile/storage-routing/wallpaper files have unchanged source fingerprints from the end of R1 and are not expanded into another review scope here. Domain-worker implementation, reference products and historical evidence remain outside scope.

**Attribution correction to R1:** Messages about compilation, test counts, repairs, observer failures, candidate manifests and execution status were **Main agent feedback**, not human manual acceptance. R1's references to the “human subsequently reported” those implementation/test developments must be read with that correction. R1 is retained as historical evidence rather than rewritten. Neither those messages nor this source verdict establishes a human GUI/physical acceptance gate. The specification's recorded approval is a separate contract fact.

During this re-review Main first reported r4 focused 119 tests / 8 failures attributable to the fixture's `/var` alias, then changed/refroze only the store's path-admission guard and its test fixture. This reviewer refreshed both files before this verdict. Main subsequently reported r5 focused 119 / 0 and full r3 2533 / 0, with all six new regression methods executed. These are attributed Main reports; no result log was independently inspected. The prior full r2 2527 / 0 predates these safety repairs and is not verification of them. Main described the earlier candidate as superseded/unaccepted and reported Debug/Release R2 packaging still running plus a 429-input source manifest including resources; none is treated here as independently verified packaging, candidate, or runtime acceptance.

## Finding dispositions

| Original finding | Original severity | Refreshed source | Disposition |
| --- | --- | --- | --- |
| F1: duplicate preference fields remain writable ambiguity | P1 | `AppLibraryStore.swift:187–252` | Resolved at source level |
| F2: protected-target/path checks separated from replacement | P1 | `AppLibraryStore.swift:47–144`, `167–184` | Resolved within the clarified cooperating-writer contract |
| F3: older successful save forgotten after latest failure | P2 | `AppLibraryPreferencesCoordinator.swift:8–9`, `54–73`, `92–96` | Resolved for successful-receipt bookkeeping and terminal reconciliation |
| F4: equal retry bypasses an incomplete flush | P2 | `AppLibraryStore.swift:75–88`, `167–184` | Resolved at source level |

### F1 — decoded object keys are checked before dictionary selection

`decode` rejects duplicate object keys at lines 192–193 before `JSONSerialization` or payload decoding chooses a value. The preflight maintains a separate set for each object and an array marker for each array; it skips complete string literals, decodes prospective key strings, and therefore compares escaped and literal equivalents. Nested object keys are included rather than only root version declarations. String values/key-like content and keys in distinct objects do not become the same object's duplicate declaration. The later Foundation parse still validates syntax; the preflight is not being treated as a full JSON parser.

Exact root and preferences key sets are checked at lines 206–211. A duplicate becomes `.ambiguousSchema`, and save admission at 173–176 refuses it even during explicit corrupt recovery. Future/oversized/non-UTF-8 protection remains in place. A single escaped valid v1 key is still admissible.

The five fixtures in `AppLibraryStoreTests.swift:158–175` cover duplicate root preferences, duplicate enabled, escaped enabled, duplicate override and escaped override keys, checking `.protectedPayload`, original bytes and zero writes. The existing escaped-header/string-content positive case remains at 152–155. This reviewer inspected these assertions without executing them.

**Independent conclusion:** F1's writable duplicate-key ambiguity has been closed. Confidence: high in source control flow.

### F2 — conditional admission and replacement share cooperating-writer ownership

`save` captures the actual inspected bytes at 170–176 and passes those bytes, including nil for absence, into replacement at 183. Local replacement opens a stable `.library.lock`, verifies it is regular, and acquires a nonblocking exclusive advisory lock at 50–56. It compares the target with the expected bytes under that lock before temporary-file creation, then compares again immediately before replacement. A different participating writer's completed commit therefore invalidates the stale expected bytes; a busy lock fails without overwriting the preferences.

All directory components are opened relative to the previous directory descriptor with `O_DIRECTORY | O_NOFOLLOW`. Only edit-time traversal calls `mkdirat`; load-time absence creates neither directories nor locks. Temporary creation, target reads, replacement and cleanup use `openat`, `renameat` and `unlinkat` against pinned directory descriptors. Target reads verify the opened file is regular. The pinned/current directory device and inode comparison at 77–83 rejects a directory substitution observable at that checkpoint. Cleanup remains anchored even after a directory is moved.

The refreshed guard at 121–125 rejects literal dot/dot-dot components and delegates actual symbolic-ancestor rejection to descriptor traversal. It no longer equates safety with Foundation's standardized-URL spelling. The fixture now uses Darwin `realpath` at `AppLibraryStoreTests.swift:42–50` to supply a canonical temporary-directory path. This removes the reported `/var` fixture issue without making the production walker follow actual symbolic ancestors.

The test hook defaults to nil and is absent from production store construction. Test sources cover a changed future target at 177–185, an ancestor replaced by a symlink at 188–206, and an already held cooperating lock at 209–221. The source's inode check additionally handles an observable plain-directory substitution, although that distinct branch is not demonstrated by the symlink fixture alone.

**Independent conclusion:** F2 is closed within the explicit supported contract: cooperating Launchcopy writers in the private local directory, with no participating writer changing the lock/namespace while a transaction runs. The compare-to-bytes admission is a coordinated conditional commit, not a kernel atomic CAS against arbitrary processes. Advisory locks do not control non-participating editors, and another namespace change can occur after the last check. Source comments and the refreshed specification expressly exclude that guarantee. No unconditional race-proof claim is made. Confidence: high in the supported source mechanics; filesystem execution was not independently observed.

### F3 — successful receipts survive presentation supersession

After each serial save returns, lines 59–63 record every `.saved` receipt's preferences and generation before the active/latest-generation presentation gate. Thus B's successful receipt is retained even while superseding C is pending. When the latest request terminates, lines 69–72 reconcile committed/load presentation to the retained successful baseline rather than to stale A or failed C. `latestSaveResult` remains C's failure, and drain returns failure/read-only rather than converting an older success into a successful receipt for C. Invalidation still suppresses UI callbacks without cancelling accepted saves.

`AppLibraryPreferencesCoordinatorTests.swift:108–137` models B saved / C failed, checks B's retained receipt while C is pending, checks terminal reconciliation, then derives a subsequent draft from B and verifies that both B's existing override and the new override are retained.

**Independent conclusion:** The specific R1 F3 sequence is repaired. `persistedPreferences` denotes the last acknowledged successful receipt; it does not independently prove the bytes currently visible after a later post-rename failure or after a different process's commit. The approved failure/Cancel drain boundary remains necessary. Confidence: high in source ordering and receipt bookkeeping.

### F4 — equality can no longer manufacture a successful receipt

There is no loaded-equal early return in refreshed save admission. Any admissible draft, including a retry identical to currently readable bytes, is encoded and sent through replacement. Local replacement writes/fsyncs its temporary descriptor, performs the conditional rename and fsyncs the pinned directory before returning success. Consequently an identical retry after a failed directory flush cannot report `.saved` merely because a read sees equal data.

`AppLibraryStoreTests.swift:224–234` uses an I/O fixture that installs bytes and then throws once. It checks the failed receipt, readable-but-unacknowledged contents, a successful identical retry, and two replacement calls. This is relevant receipt-path coverage; the fixture does not simulate actual storage-device flush or prove physical durability.

**Independent conclusion:** F4's equal-content flush bypass is closed. Confidence: high in source control flow.

## Remaining boundaries, not hidden completion claims

- Failure after rename can leave newly readable bytes with an unsuccessful flush receipt. Removing the equality shortcut makes retry honest; it does not roll back that indeterminate operation or transform the coordinator's previous acknowledged baseline into a filesystem readback guarantee. The current source continues to report failure and drain failure. Physical restart/power-loss behavior remains unproven.
- The actor and predecessor chain still serialize accepted writes. Drain remains a monotonic-deadline polling design that does not abandon or cancel an accepted writer on timeout. No wall-clock or native Quit integration was tested by this reviewer.
- Descriptor anchoring prevents following symbolic ancestors into a different tree; it does not promise atomic namespace stability against arbitrary malicious/non-cooperating edits. Future edits to the coordination contract must preserve this limit.
- Reads remain bounded to 1 MiB plus one distinguishing byte and check descriptor type before reading contents. The source does not establish that opening every possible device has zero side effects; private cooperating-directory ownership remains part of its supported setting.
- Prior projection coalescing/cancellation/generation/observer repairs and test-profile-only wallpaper source-inspection construction are unchanged by this repair. Their R1 source observations remain limited to those construction paths, not overall production performance or independent runtime proof.
- The native Library owner, Settings/navigation/detail/category controls, shared actions, source-generation wiring and actual Quit wiring are still absent by design at this foundation checkpoint. No Library feature PASS is issued. Current candidate identity, Debug/Release/package results, GUI/accessibility, physical/model parity, restart durability and performance are separate gates. The Full Goal remains active.

## Verification and fingerprints

Independent reviewer executions: **zero tests, zero Swift/build/package commands, zero evidence/log reads**. Test counts and execution claims above are Main agent feedback only. This source PASS does not depend on assigning independent test credit to r4, r5, full r3, or packaging.

Final reviewed SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryStore.swift` | `f8b2560042a5ef3df7dbcf186198114de2f7ea51e1c64611fbc2182ed22f4464` |
| `Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift` | `6f7eace8b72adb6b50603f8d0c4044008c85c4b04c5cba6946f718be95a0219c` |
| `Tests/PagingUITests/AppLibraryStoreTests.swift` | `30d42e65280427b9123f1977a08f1bf07382215a1cae488e4ed3df99ee0e8b7c` |
| `Tests/PagingUITests/AppLibraryPreferencesCoordinatorTests.swift` | `3004a0ded75acc6093c9b33bb97fc5566bfdad88dfee902bd09219766ee3b032` |
| Preserved `Workflow/results/APP_LIBRARY_MAIN_FOUNDATION_REVIEW.md` | `aae57fdf5811e20fae05177eb39e5011a5abfa9fc33ce7ce3e8977092a11024c` |

No implementation repair is requested for F1–F4 by this re-review. Main may proceed with the separately authorized integration and verification work while retaining these source/runtime/physical boundaries.
