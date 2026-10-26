# B1 journal temporary cleanup repair

Status: implemented in the root working tree; static inspection only. No build,
test execution, application launch, network operation, publication, or real-data
cleanup was performed by this worker. Independent review and Main's fresh
post-integration verification remain required.

## Exact changes

- `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`: replace only the body
  of `cleanupTempFiles()`. Require a retained `LayoutStoreLock`, then request
  removal of the two exact slot temporary filenames. Remove directory enumeration
  and suffix matching. Startup and reset share this guard. Preserve reset's
  existing predecessor/writer wait and all archive, schema, write, flush and retry
  behavior. The file already contained unrelated lifecycle changes before this
  worker began; those were retained.
- `Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift`: document the narrowed
  removal contract and replace recursive FileManager deletion with an exact-name
  allowlist, a directory descriptor opened with `O_NOFOLLOW`, `fstatat` with
  `AT_SYMLINK_NOFOLLOW` requiring a regular file, and `unlinkat` without
  `AT_REMOVEDIR`. Missing/inaccessible/nonregular entries are silently preserved.
  No other I/O method changed.
- `Tests/AppGridUITests/LayoutStoreTemporaryCleanupTests.swift`: add eight tests
  using unique owned synthetic sandboxes only: exact-name regular-file cleanup
  under the real lock; unrelated `.tmp` file/directory and near-match preservation;
  recognized symlinks to files/directories and recognized directory preservation;
  reset cleanup under lock; reset protected-entry preservation; no-lock peer and
  failed-lock cleanup exclusion for load/reset; direct production removal guards
  for unrelated names/dangling links and a symlinked store directory. Record
  removal requests and assert zero directory enumeration where applicable.
- This result file.

`Tests/AppGridUITests/LayoutStoreActorTests.swift` is byte-for-byte unchanged
from the worker's in-session baseline; no existing cleanup assertion needed
adjustment. No AppDelegate, unavailable-store, type, composition-test, package,
workflow-state, or other peer-owned file was edited.

## Evidence and limits

- Existing-file `git diff --check` completed with no diagnostics. New-file
  whitespace checks and the final source-only delta were inspected separately.
- The new test methods were authored, not compiled or executed. No test PASS or
  production/runtime acceptance is claimed. Main's active old-export test run
  cannot establish acceptance of these edits.
- Tests that inspect reset with protected entries or a no-lock peer intentionally
  reject the subsequent write before it touches disk. This isolates cleanup;
  the existing write path and cross-process last-writer-wins behavior are unchanged.
- The directory descriptor anchors inspection/removal, and unlink cannot recurse
  or remove a directory. The regular-file check and unlink remain separate POSIX
  operations: this is not an atomic guarantee against an external process swapping
  a regular file for a symlink between those operations. Existing store-lock
  coordination is required; adversarial cross-process replacement and ancestor
  path hardening are outside this bounded cleanup repair.
