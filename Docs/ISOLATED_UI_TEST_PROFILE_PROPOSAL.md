# Isolated UI Test Profile — Approved Implementation Specification

Date: 2026-10-13

## Problem and outcome

The desktop is now accessible through CUA, but windowed mode currently uses the
same workspace directory and named preference suites as the resident product.
Starting a second candidate is not storage isolation. GUI organization/alias tests
must not overwrite the user's existing arrangement or unregister the resident
instance's activation services. An unshown AppKit integration test is not an
exact-candidate GUI or true process restart gate.

## Proposed scope and interface

Add an explicit opt-in named test profile, valid only with --ui-test-windowed.
Production defaults, storage schemas, paging parameters and normal window policy
remain unchanged. Restrict profile IDs to a bounded neutral ASCII identifier.
Derive layout storage and test-only preference namespaces deterministically from
that identifier and a controlled candidate-local test root. Reject an invalid or
nonisolatable profile; do not silently fall back to production storage.

Use isolated synthetic .app metadata packages for mutating GUI tests. Read real
icons only for a separately authorized read-only visual pass. Do not copy reference
resources, telemetry app identities, or write folder/alias values into logs. Never
set or unregister the resident product's global activation bindings. Skip global
activation and login-item installation for a profile; keep test-instance menu,
search, folder, appearance and paging flows. No system accessibility/preferences
changes and no automatic distribution/install/signing.

## Acceptance and delivery

Pure path/namespace/parser tests, two-profile isolation, invalid input rejection,
future-schema protection, production default regression, and Main-owned build.
Exact candidate CUA runs use Desktop2 or the ordinary test window, not screen
covering. Verify actual title click/edit/Enter/Escape, hide/restore/aliases,
assignment, save-failure cancellation, successful test-instance Quit and restart.
Stop only the specifically launched test instance via its own normal Quit; do not
stop the user's resident application. Preserve test artifacts for evidence.

Different test configuration is disclosed: it cannot certify production global
activation, login items, 120Hz or full-screen physical performance. Those gates
remain separate. An independently reviewed test profile is a safety prerequisite,
not a shortcut to a production acceptance claim.

## Decision

User explicitly confirmed the recommended isolation and normal test-instance Quit
on2026-10-13. Cross-module implementation is authorized within this scope. Existing
Quit failure policy is separately approved and implemented; this proposal does
not defer or change that policy. Continue non-destructive source/test/build work
while this test-isolation decision is pending.

## Confirmed implementation decisions

CLI: --ui-test-profile <id> requires --ui-test-windowed; lower-case ASCII ID
1–48 characters. Only a canonical .app under .build/candidates may resolve a
profile. Candidate-local UITestProfiles/<id> contains the workspace and synthetic
Applications. Hashed candidate identity + profile separates named preference
suites, stable across restart of the same candidate. Invalid path/ID has no
production fallback. Runtime composition uses fake/no-op global activation and
login adapters; opening settings cannot invoke real system registration. Only
the isolated synthetic catalog roots are admitted by the writable profile.

## Existing dependency contract repair — I1

The ordinary scanner promised followDirectorySymlinks=false by default but only
enforced it on linked .app entries. Apply the same existing flag to every entry
before resolving/descent; preserve explicitly configured true behavior. This
is a bounded documented-contract bug fix, not a new scanner API or user-facing
source policy. Actual configured-profile scanner/metadata reader and resolver
regressions are required; clean hand-made fixtures alone do not unlock GUI.
