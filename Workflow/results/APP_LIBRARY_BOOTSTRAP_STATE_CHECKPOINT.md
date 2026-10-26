# App Library bootstrap state — verified code checkpoint

Date: 2026-10-15. Full parity goal remains ACTIVE and incomplete.

## Delivered scope
The approved optional, default-off same-window App Library is implemented: categories, factual details, independent search, manual category/Automatic, reuse of hidden/alias actions, and grid context restoration. No usage history is recorded. This checkpoint adds two bounded state repairs to the prior native implementation:

1. Before the first canonical catalog exists, initial scan and retry show loading rather than unavailable. Owner state is seeded from the existing refresh controller and updated through the final production callback composition.
2. A closed, discarded source projection no longer masks completed source failure as loading. Only an open projection contributes pending work. Action revocation, cancellation and generation ownership remain unchanged.

An unrelated full-suite failure exposed a scheduling-sensitive test expectation. Existing store flush permits both nothingPending and a joined successful persisted receipt. Only the intended test helper accepts both, with exact write generation 2/3; autonomous successor progress, six attempts, one writer, exact completed layout sequence and validated layout 4 remain mandatory. Production storage was not changed. Initial misplaced assertion failed compilation; the wrong site was restored exactly and this history is retained.

## Executed evidence — Main
- Bootstrap red: 1 XCTest / 2 failures (red.log).
- Discarded-worker red: 1 XCTest / 2 failures (discarded-worker-red.log).
- Intermediate full run: 2588 / 1 failure in preexisting receipt expectation (full-r1.log); not PASS.
- Initial assertion placement compile failure: focused-r3.log; zero executed test credit.
- Repaired focused runs: 35/0, 47/0, final 23/0. Overlapping, not additive.
- Final full run: **2589 XCTest / 0 failures**, 53.554 seconds (full-r2.log). Separate Swift Testing runner executed zero tests and is not counted.
- Debug build, Release package and git diff --check passed.
- Packaged localization: 3 languages / 274 keys and signatures. Positive probe and missing Library key / invalid placeholder negative probes passed.
- 440 current source/test/script/resource hashes match. All 18 PagingCore/PagingUI source hashes match prior native checkpoint; physics/Timer defaults unchanged.

Evidence root: /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-bootstrap/

## Independent review
APP_LIBRARY_BOOTSTRAP_STATE_REVIEW_R2.md: bounded source PASS after initial finding repaired.
LAYOUT_TERMINAL_RECEIPT_EXPECTATION_REVIEW.md: bounded test-source PASS, high confidence.
Reviewer executed zero builds/tests. Earlier pending full-run notes reflect report-time status; Main's later full result is above. Historical findings and intermediate failures retained.

## Exact deliverable
Unsigned, uninstalled isolated candidate:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-bootstrap-rc-20261015-r1/LaunchcopyUITest.app

Executable SHA-256:
27bcafb691e0a419852006341dbf7d6b08f2adf505f75e85ffda1dc25a94de86

Dedicated metadata selects candidate-local gui data and ordinary non-topmost window. Forty independently generated Info-only fixtures are prepared; not real-launch evidence. Existing candidates/formal user data untouched. No install/sign/publish/commit or unrelated process shutdown. Build completed; reviewer closed.

## Remaining acceptance / next actions
Current-turn supported desktop access returned Mac locked. No test application started; no native acceptance credited. Manual-unlock question already exists; no duplicate request or workaround.

After unlock, directly open this exact isolated candidate using supported controls. Test default-off/enable, categories/search/details/manual/Automatic, row keyboard navigation versus explicit Details, hidden/alias reuse, Back context and source-failure states. Normal Quit and same-candidate restart must verify actual persistence. Tests do not prove GUI, VoiceOver, crash recovery, real fsync, physical smoothness or 120Hz acceptance.

Broader parity ledger remains authoritative: capacity and other unapproved contracts await decisions; wallpaper source-open condition and >25ms hitch causality remain unresolved. This successful bounded repair does not complete or shrink the goal.
