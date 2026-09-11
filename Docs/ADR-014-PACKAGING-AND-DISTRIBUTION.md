# ADR-014 — Packaging and Distribution Readiness (Phase 1H)

- **Status**: ACCEPTED (Gate 0 2026-09-11)
- **Product**: Launchcopy (`com.launchcopy.app`)

## Context

Phase 1G delivered resident launcher activation. Phase 1H prepares a product shell and local `.app` packaging without authorizing release submission.

## Decisions

1. **Public name** Launchcopy; internal SwiftPM executable may remain `PagingPrototypeApp`.
2. **Bundle ID** `com.launchcopy.app`.
3. **Distribution posture**: GitHub open-source + direct-distribution readiness. User performs publish. This phase does not auto `git push`.
4. **Four-finger**: Direct builds keep private MultitouchSupport with Enabled≠Ready UI. Document notarization / Mac App Store conflict honestly — do not claim MAS eligibility while private API remains.
5. **Launch at Login**: `SMAppService.mainApp`, default off; real enable requires separate user authorization.
6. **Packaging**: `Scripts/package-app.sh` assembles an **unsigned** local `.app` for structure validation only.

## Consequences

- Notarization of a build that links MultitouchSupport private symbols may fail or require hardened-runtime exceptions — treat as `BLOCKED_BY_PRIVATE_API` for notarized shipping until a policy change.
- Open-source consumers building from source accept private-framework risk on their machines.
- Login item registration must never run in automated tests.

## Verification

- `plutil -lint` on bundled Info.plist
- Bundle layout: `Contents/MacOS`, `Info.plist`, `PkgInfo`
- Exact identity fields match Gate 0
