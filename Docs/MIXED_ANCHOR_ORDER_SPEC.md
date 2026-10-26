# Stable missing-anchor order for mixed workspaces

Date: 2026-10-20. Selected correctness follow-up to the approved whole-code audit. Not a visual-neighbor navigation redesign.

## Problem and policy
Mixed app/folder missing-anchor fallback compares hashValue, which is randomized across processes and permits collisions between distinct identities. The existing five-level contract requires deterministic identity comparison, while preserving composition order.

Choose the existing domain ordering rather than inventing visual-neighbor semantics: retain actual current cross-kind rank apps-before-folders (the old comments incorrectly say folder-first). Within apps, reuse the exact AppID.anchorOrderLessThan predicate already used by CatalogPlanner: bundle-ID variant before canonical-URL fallback variant, lexical stored values within a variant. Expose this Boolean predicate across package targets without returning raw storage or adding Comparable conformance. Within folders, use an internal Boolean lexical canonical UUID-string comparison; no UUID/name/path getter or logging.

The provider first locates an equal surviving anchor; if absent, it chooses the FIRST entry in CURRENT composition whose identity is greater, else the LAST lower entry, else page0. Do not sort that array or choose a semantic-minimum successor. Empty/nil handling and exact app-only delegation remain, including a vanished folder anchor projected to nil in an app-only composition. This fixes an implementation mismatch with the existing stable-order contract, not the saved arrangement or app-only policy.

## Scope / preservation
Only AppID comparator visibility/documentation, internal FolderID comparison, provider same-kind comparison/documentation and one new provider test file. AppID/FolderID storage, equality/hash behavior, redacted descriptions, codecs/schemas, durable/latent order, catalog/search/folder generations, counts, defaults, physics/layout/input remain unchanged. Never use hash values as ordering keys, debug descriptions or reflection as ordering data, or expose original identity strings in diagnostics. No global deterministic-hash setting or persisted data rewrite.

## Acceptance / evidence
Use existing public provider APIs and synthetic records/fixed fixture UUIDs only, no actual apps/files/windows. Tests must compile against the original baseline without new comparator API calls. Cover multi-page missing app/folder successor and predecessor with displaced surviving entries, actual app-before-folder rank, app-ID variant ordering, arbitrary presentation order preserved, located/nil/empty and exact app-only delegation. Assert exact outcomes/pages and unchanged durable input, not single-page coincidental outcomes.

Run several FRESH test processes in default randomized hash mode for old and current builds, clearing only the child process SWIFT_DETERMINISTIC_HASHING override if inherited; do not invent/control a specific seed or weaken production hashing. Retain exact observed old failures/outcomes (old randomness need not fail every run); current cases must all pass across processes. Restore exact source bytes in finally after old replay. Ordinary existing controls, focused/full tests, Debug/Release unsigned isolated packaging/diff and bounded independent review on frozen inputs. No native visual/physical/performance acceptance inferred.

## Ownership / maintenance / boundaries
Main owns the three production files and fresh-process proof. One worker owns only Tests/AppGridUITests/MixedAnchorRemappingTests.swift. Later independent read-only reviewer owns one report; max3includingMain, serial SwiftPM. Preserve dirty baseline and earlier patches. Runtimefd395b00 untouched, latest2f534bff candidateunlaunched. No first-hitch profiling (user-deferred, CPUcauseunproven), source-reference/formal-data/OS/UI/process-signal/install/sign/publish/Git action. Existing automated suites may use owned temporary fixtures. Full parity incomplete; prior goal turn was concrete diagnostic ownership repair progress.
