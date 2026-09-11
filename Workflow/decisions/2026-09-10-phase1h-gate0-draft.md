# Phase 1H Gate 0 — Draft decision packet (pending Bundle ID + GitHub-boundary confirm)

- **Date**: 2026-09-10
- **Prompt**: `Docs/PHASE1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS_PROMPT.md`
- **Prompt SHA-256**: `8634c050773b710b3c47224906d0f354d34d5f688d0f0fa271b741cd44292ace`
- **Status**: DRAFT — user answered D1–D6 partially; Bundle ID and GitHub-boundary wording awaiting final confirm before `APPROVED` and before any product source edits.

## 1. Phase 1G reconciliation (honest)

| Layer | Status | Evidence / note |
|---|---|---|
| Automated implementation | **COMPLETE (practical)** | T-1G-B…E + four-finger wiring; last recorded full suite **1468/0** at T-1G-E; subsequent smoke fixes (borderless teardown, Multitouch callback box, folder drop/move-out, preview) were user-validated in chat |
| User-reported practical acceptance | **RECORDED** | User stated 「修好了」after folder move-out preview fix; earlier 「好像成功了」for four-finger wake |
| Evidence-backed physical gates | **NOT PASS — carried as debt** | M01–M12 full matrix, energy A/B, multi-display, sleep/lock, rapid-race, 120Hz, Phase 1F B10/B11 — **no repository PASS evidence**; will **not** invent `PASS` |

Workflow phase label remains conceptually:

`PHASE1G_AUTOMATED_COMPLETE_PHYSICAL_PENDING` + **user practical acceptance input recorded for Gate 0**.

Activation Settings menu item is still a **stub** (`StatusItemController`).

## 2. Proposed Phase 1H boundary

In: single-instance Activation Settings window; transactional apply/rollback; Launch at Login via `SMAppService` (default off); product identity (Launchcopy); reproducible local `.app` packaging; signing/sandbox/notarization **feasibility docs**; product vs diagnostic separation; tests + manual matrix + independent review.

Out without new approval: publish/upload, real signing/notarization submission, enabling login item on the user machine without a separate announcement, MAS shipping, gesture redesign, forbidden-source visual copy, git commit/push/tag (unless later explicitly approved).

## 3. User decisions so far (D1–D6)

| ID | Decision | User answer |
|---|---|---|
| D1 name | Public product name | **Launchcopy** (internal module may remain `PagingPrototype`) |
| D1 Bundle ID | — | **PENDING** (recommendation: `com.launchcopy.app`) |
| D2 distribution | GitHub public | User will publish on GitHub; treat as **open-source / direct-distribution readiness**, not MAS-first |
| D3 four-finger | Keep private MultitouchSupport in direct builds + explicit Ready/error UI | Accepted (recommended) |
| D4 login item | Implement setting, default off; real enable needs separate user authorization | Accepted (recommended) |
| D5 settings UX | Native AppKit preferences window | Accepted (recommended) |
| D6 locale | Chinese UI primary; localization-ready string boundary | Accepted (recommended) |

## 4. Files expected to change (after APPROVED)

- New: Settings window / apply planner / `SMAppService` adapter / packaging scripts / entitlements inventory docs
- Touch: `AppDelegate`, `StatusItemController`, `ActivationPreferences`/`ActivationSettings`, `AppMain`, `Package.swift` only if required for app-bundle metadata (Main-owned)
- Docs: ADR updates, PHASE1H_SPEC/REPORT, PRIVACY_DATA_MAP, PROVENANCE as needed
- Tests: preferences apply/rollback, settings UI logic with fakes, packaging smoke checks

## 5. Validation gates (preview)

- Automated: settings domain + apply plan + fake login-item adapter + existing activation regression suite green with executed count > 0
- Manual: settings open single-instance; apply/rollback; shortcut/hot-corner/four-finger status presentation; login-item **UI only** unless separately authorized
- Packaging: reproducible `.app` build instructions + inventory; notarization/private-API conflict documented honestly
- Physical 1G debt remains named PENDING unless new evidence arrives

## 6. Risks and rollback

- Private MultitouchSupport vs notarization / future MAS — document, do not conceal
- Login item: never register for real in automated tests; machine enable is opt-in and reversible
- Identity rename: public strings/bundle first; avoid mass internal rename unless value is clear
- Rollback: keep Activation Preferences suite injectable; feature flags / default-off for login item and any new services

## 7. Stop condition

**No product source implementation until** Bundle ID + GitHub-boundary confirmation, then this file promoted to `APPROVED` (or superseded by a final `…-approved.md`).
