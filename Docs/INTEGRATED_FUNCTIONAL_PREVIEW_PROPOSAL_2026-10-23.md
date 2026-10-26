# Integrated functional preview proposal

Date: 2026-10-23. Status: PROPOSED; implementation requires the user's decision below.

## Problem and intended outcome
The ordinary isolated UI entry can launch only the owned synthetic catalog and intentionally uses fake global services. The separately approved real-gesture harness supports real four-finger input but deliberately blocks app launches and uses non-executable placeholders. These environments successfully isolate evidence but are not an integrated end-user experience; the user reasonably reported app clicks as broken in the gesture harness. The full goal is a usable independent LaunchBetter-like experience on Launchcopy, not permanently split test modes.

## Proposed next scope
A separately identified, normally windowed, uninstalled integrated preview: read the existing bounded default local application roots; show real installed application names/icons; route actual launch through the existing validated shared NSWorkspace executor; use the already implemented/accepted real four-finger backend for inward Show and opt-in outward Hide. Keep layout and all writable preferences in its own profile, never import or overwrite formal data. No arbitrary directory expansion or profile escape/fallback. Do not modify the two existing isolated entry capability contracts.

Keep application Trash/removal and other destructive actions unavailable; usage recording absent/disabled with no history import; shortcut/hot-corner/login/global-session settings not enabled by this preview. No install/sign/notarize/publish, background credential/permission changes, system UI changes, app-source relocation, user-app launches by the agent during tests without a bounded target decision, or raw app inventory/search/input logging. User initiates real app launches. Do not open developer reference trees or copy their source/assets.

## Architecture direction after approval
Write a specific implementation specification and entry/storage/capability tests before edits. Prefer a narrow distinct composition over patching `uiTestProfile` or weakening `GestureValidationPolicy`. Reuse current app catalog, launch, paging, folder, presentation and persistence owners; do not fork a second launcher. Keep ordinary non-topmost test window and explicit executable identity visible. Validate correct profile resolution, default limited settings, real catalog read vs isolated writes and strict rejection on bad configuration.

## Acceptance and unresolved gates
Static/unit acceptance is not integrated native/physical acceptance. Record packaging/resource/source identity, non-destructive startup and independent review; actual user real-app click plus outward/inward behavior in this single environment must be tested. Catalog privacy, persisted identifiers and launch permission boundaries need explicit approved spec. Real IME/spoken VoiceOver/performance/120Hz/other reserved variants remain separate. Proposal approval does not establish full parity, install authorization or permission to delete user apps.

## Decision requested
Approve this bounded integrated preview, or retain separate environments for now. Recommended: approve integrated preview with isolated storage and non-destructive capabilities, because it materially advances the real combined product experience.
